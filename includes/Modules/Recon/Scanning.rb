# frozen_string_literal: true

module M_Scanning

    #
    # https://github.com/libwifi/libwifi/blob/main/src/libwifi/core/misc/security.h (L85 at L89)
    #
    SECURITY_TYPE_VALUES = {
        'WEP' => 0x01,
        'WPA' => 0x02,
        'WPA2' => 0x03,
        'WPA3' => 0x04
    }.freeze

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

    private def preload_ouis(macs)
        @oui_cache ||= {}
        @oui_mutex ||= Mutex.new

        ouis_to_fetch = macs.map { |mac| mac.split(':')[0..2].join }.uniq
        ouis_to_fetch.reject! { |oui| @oui_mutex.synchronize { @oui_cache.key?(oui) } }

        return if ouis_to_fetch.empty?

        # Concurrency limit of 10 threads
        ouis_to_fetch.each_slice(10).each do |slice|
            slice.map do |oui|
                Thread.new do
                    begin
                        response = self.call(
                            'GET',
                            ("helpers/lookupOUI/#{oui}"),
                            '',
                            '{"available":'
                        )
                        result = response.available ? response.vendor : 'Unknown Vendor'
                        @oui_mutex.synchronize { @oui_cache[oui] = result }
                    rescue StandardError
                        @oui_mutex.synchronize { @oui_cache[oui] = 'Unknown Vendor' }
                    end
                end
            end.each(&:join)
        end
    end

    private def lookup_oui(mac)
        @oui_cache ||= {}
        @oui_mutex ||= Mutex.new
        oui = (mac.split(':')[0..2].join)

        @oui_mutex.synchronize do
            return @oui_cache[oui] if @oui_cache.key?(oui)
        end

        response = self.call(
            'GET',
            ('helpers/lookupOUI/' + oui),
            '',
            '{"available":'   
        )

        result = (response.available) ? response.vendor : 'Unknown Vendor'
        @oui_mutex.synchronize { @oui_cache[oui] = result }
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
                "band" => band
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

    public def output(scanID)

        response = self.call(
            'GET',
            ('recon/scans/' + scanID.to_s()),
            '',
            '{"APResults":['
        )

        all_macs = []

        ap_results = response.APResults || []
        ap_results.each do |ap|
            all_macs << ap.bssid
            ap.clients&.each { |client| all_macs << client.client_mac }
        end

        unassociated_results = response.UnassociatedClientResults || []
        unassociated_results.each { |client| all_macs << client.client_mac }

        outofrange_results = response.OutOfRangeClientResults || []
        outofrange_results.each { |client| all_macs << client.client_mac }

        self.preload_ouis(all_macs)

        ap_results.each do |ap|
            ap.oui = self.lookup_oui(ap.bssid)
            ap.encryption = self.convert_encryption(ap.encryption)
            ap.clients&.each do |client|
                client.client_oui = self.lookup_oui(client.client_mac)
            end
        end
        response.APResults = ap_results

        unassociated_results.each do |client|
            client.client_oui = self.lookup_oui(client.client_mac)
        end
        response.UnassociatedClientResults = unassociated_results

        outofrange_results.each do |client|
            client.client_oui = self.lookup_oui(client.client_mac)
        end
        response.OutOfRangeClientResults = outofrange_results

        return(response)

    end

    public def tags(ap)
        self.call(
            'POST',
            'recon/tags',
            {
                "scan_id" => ap.scan_id,
                "bssid" => ap.bssid
            },
            '[{"scan_id":'   
        )
    end

    public def deauth_ap(ap)

        clients_mac = []
        ap.clients&.each do |client|
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

    public def deauth_aps(aps)
        # Concurrency limit of 10 threads
        aps.each_slice(10).each do |slice|
            slice.map do |ap|
                Thread.new { self.deauth_ap(ap) }
            end.each(&:join)
        end
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