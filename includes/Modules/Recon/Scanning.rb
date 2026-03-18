module M_Scanning

    #
    # https://github.com/libwifi/libwifi/blob/main/src/libwifi/core/misc/security.h (L85 at L89)
    #
    SECURITY_TYPE_VALUES = {
        'WEP' => 0x01,
        'WPA' => 0x02,
        'WPA2' => 0x03,
        'WPA3' => 0x04
    }

    private def convert_encryption(encryption)
        if (encryption == 0)
            return('Open')
        end

        SECURITY_TYPE_VALUES.each do |key, value|
            if (!encryption.nil? && (encryption & (1 << value)) != 0)
                return(key)
            end
        end

        return('Unknown')
    end

    private def lookup_oui(mac)
        @oui_cache ||= {}
        @mutex ||= Mutex.new
        oui = (mac.split(':')[0..2].join)

        @mutex.synchronize do
            return @oui_cache[oui] if @oui_cache.key?(oui)
        end

        response = self.call(
            'GET',
            ('helpers/lookupOUI/' + oui),
            '',
            '{"available":'
        )

        result = (response.available) ? response.vendor : 'Unknown Vendor'
        @mutex.synchronize do
            @oui_cache[oui] = result
        end
        return(result)
    end

    public def start(scan_time, band = '2')

        response = self.call(
            'POST',
            'recon/start',
            {
                "live" => false,
                "autoHandshake" => false,
                "scan_time" => (scan_time == 0) ? 30 : scan_time,
                "band" => "2"
            },
            '{"scanRunning":true,"scanID":'   
        )

        total = (scan_time + 5)
        progressbar = ProgressBar.new('Progression of the recon scan [:bar]', width: 100, total: total)
        total.times do
            sleep(1)
            progressbar.advance
        end

        return(response)
        
    end

    public def start_continuous(autoHandshake, band = '2')
        response = self.call(
            'POST',
            'recon/start',
            {
                "live" => false,
                "autoHandshake" => autoHandshake,
                "scan_time" => 0,
                "band" => band
            },
            '{"scanRunning":true,"scanID":'   
        )
        sleep(5)
        return(response)
    end

    public def stop_continuous()
        self.call(
            'POST',
            'recon/stop',
            '',
            '{"success":true}'   
        )
    end

    private def preload_ouis(macs, concurrency = 10)
        return if macs.nil? || macs.empty?
        @oui_cache ||= {}
        @mutex ||= Mutex.new

        unique_macs = macs.uniq
        pending_macs = []
        @mutex.synchronize do
            pending_macs = unique_macs.reject { |mac| @oui_cache.key?(mac.split(':')[0..2].join) }
        end

        return if pending_macs.empty?

        queue = Queue.new
        pending_macs.each { |mac| queue << mac }

        workers = [concurrency, pending_macs.size].min
        threads = workers.times.map do
            Thread.new do
                until queue.empty?
                    mac = nil
                    begin
                        mac = queue.pop(true)
                    rescue ThreadError
                        break
                    end
                    self.lookup_oui(mac) if mac
                end
            end
        end
        threads.each(&:join)
    end

    public def output(scanID)

        response = self.call(
            'GET',
            ('recon/scans/' + scanID.to_s()),
            '',
            '{"APResults":['
        )

        ap_results = response.APResults || []
        unassociated_results = response.UnassociatedClientResults || []
        outofrange_results = response.OutOfRangeClientResults || []

        # Collect all MAC addresses for preloading
        macs = []
        ap_results.each do |ap|
            macs << ap.bssid
            ap.clients&.each { |client| macs << client.client_mac }
        end
        unassociated_results.each { |client| macs << client.client_mac }
        outofrange_results.each { |client| macs << client.client_mac }

        self.preload_ouis(macs)

        ap_results.each do |ap|
            ap.oui = self.lookup_oui(ap.bssid)
            ap.encryption = self.convert_encryption(ap.encryption)
            ap.clients&.each do |client|
                client.client_oui = self.lookup_oui(client.client_mac)
            end
        end

        unassociated_results.each do |client|
            client.client_oui = self.lookup_oui(client.client_mac)
        end

        outofrange_results.each do |client|
            client.client_oui = self.lookup_oui(client.client_mac)
        end

        response.APResults = ap_results
        response.UnassociatedClientResults = unassociated_results
        response.OutOfRangeClientResults = outofrange_results

        return(response)

    end

    public def tags(ap)
        @tags_cache ||= {}
        @mutex ||= Mutex.new
        cache_key = "#{ap.scan_id}_#{ap.bssid}"

        @mutex.synchronize do
            return @tags_cache[cache_key] if @tags_cache.key?(cache_key)
        end

        response = self.call(
            'POST',
            'recon/tags',
            {
                "scan_id" => ap.scan_id,
                "bssid" => ap.bssid
            },
            '[{"scan_id":'
        )

        @mutex.synchronize do
            @tags_cache[cache_key] = response
        end
        return(response)
    end

    public def preload_tags(aps, concurrency = 10)
        return if aps.nil? || aps.empty?
        @tags_cache ||= {}
        @mutex ||= Mutex.new

        # Filter out APs already in cache
        pending_aps = []
        @mutex.synchronize do
            pending_aps = aps.reject { |ap| @tags_cache.key?("#{ap.scan_id}_#{ap.bssid}") }
        end

        return if pending_aps.empty?

        queue = Queue.new
        pending_aps.each { |ap| queue << ap }

        workers = [concurrency, pending_aps.size].min
        threads = workers.times.map do
            Thread.new do
                until queue.empty?
                    ap = nil
                    begin
                        ap = queue.pop(true)
                    rescue ThreadError
                        break
                    end
                    self.tags(ap) if ap
                end
            end
        end
        threads.each(&:join)
    end

    public def deauth_ap(ap)

        clients_mac = []
        ap.clients.each do |client|
            clients_mac << client.client_mac
        end

        self.call(
            'POST',
            'pineap/deauth/ap',
            {
                "bssid" => ap.bssid,
                "multiplier" => 7,
                "channel" => ap.channel,
                "clients" => clients_mac
            },
            '{"success":true}'
        )

    end

    public def delete(scanID)
        self.call(
            'DELETE',
            ('recon/scans/' + scanID.to_s()),
            '',
            '{"success":true}'
        )
    end

end