module M_Authentication

    public def login()

        begin

            url = ('http://' + @host + ':' + @port.to_s + '/api/')

            response = Request.execute(
                method: :post,
                url: (url + 'login'),
                timeout: 10,
                payload: {
                    'username' => "root",
                    'password' => @password
                }.to_json,
                headers: {
                    content_type: :json,
                    accept: :json
                }
            )

            body = response.body

        rescue StandardError => exception

            abort('System::Authentication => ' + exception.message)

        else

            if (body.include?('{"token":"'))

                self.class.send(:api_url=, url)
                self.class.send(:bearer_token=, JSON.parse(body)['token'])
                self.class.send(:pineapple_host=, @host)
                self.class.send(:pineapple_mac=, @mac)
                self.class.send(:pineapple_password=, @password)
                return(true)

            else

                return(false)

            end

        end

    end

end