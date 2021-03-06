require 'rubygems' # disable this for a deployed application
require 'hotcocoa'
require "socket"
require 'net/http'
require 'uri'

framework "ScriptingBridge"

class Lamp
  include HotCocoa

  attr_accessor :pi_ip
  
  SERVER_LISTEN_PORT = 1234
  CURRENT_VERSION = 30

  def start
    init_bridge()

    app = application name: 'Lamp' do |app|
      app.delegate = self

      exit(1) unless assistive_device_enabled?

#      window frame: [100, 100, 500, 500], title: 'Lamp' do |win|
#        win << label(text: 'Hello from HotCocoa', layout: {start: false})
#        win.will_close { exit }
#      end
    end

    app.run
  end

  def init_bridge
    # voip processes to check
    @prcs = [
      {:name => 'Camfrog', 
        :ringing => false, 
        :capture => nil
      },
      {:name => "Skype", 
        :ringing => false, 
        :capture  => /Incoming call|Chiamata in arrivo|Appel entrant|Llamada entrante|Eingehender Anruf/
      }, 
      {:name => "firefox", 
        :ringing => false, 
        :capture  => /sta chiamando|is calling/
      }, 
      {:name => "safari", 
        :ringing => false, 
        :capture  => /sta chiamando|is calling/
      }, 
      {:name => "Google Chrome", 
        :ringing => false, 
        :capture  => /sta chiamando|is calling/
      }, 
      {:name => "JavaApplicationStub", 
        :ringing => false, 
        :capture => /ooVoo video call|chiamata Video ooVoo|Videochiamata ooVoo/
      }
    ]

    @ua = /Universal|Universale|Bedienungs|universel/
    
    # nome applicazione case insensitive
    @system_events = SBApplication.applicationWithBundleIdentifier("com.apple.systemevents")
    
    NSTimer.scheduledTimerWithTimeInterval 3.0,
                 target: self,
               selector: 'on_tick:',
               userInfo: nil,
                repeats: true

    @running = false

    Thread.new do
      start_udp_server
    end

    Thread.new do
      ping_udp_server
    end

    # Thread.new do
    #   sleep 2
    #   check_for_updates
    # end

  end
  
  # test
  def on_test(menu)
    Thread.new do
      switch_lamp! if udp_server?
    end
  end

  # reset
  def on_reset(menu)
    Thread.new do
      reset_lamp! if udp_server?
    end
  end

  # reset
  def on_check(menu)
    Thread.new do
      check_for_updates if udp_server?
    end
  end

  def udp_server?
    # puts "pi_ip: #{pi_ip}"

    unless pi_ip
      msg!
#      alert :message => msg, :icon => image(:file => "#{lib_path}/../resources/lamp.png")
      return false
    end

    return true
  end

  def msg!
    msg =<<-eomsg
Unable to find Lamp device: 
check lan cable connection.
    eomsg

    alert :message => msg, :icon => image(:file => "#{lib_path}/../lamp.png")

  end

  def download_msg!(link)
    msg =<<-eomsg
A new version is available. 
Please download at: 
#{link}
    eomsg

    alert :message => msg, :icon => image(:file => "#{lib_path}/../lamp.png")

  end

  def up_to_date_msg!()
    msg =<<-eomsg
Lamp is up to date.
    eomsg

    alert :message => msg, :icon => image(:file => "#{lib_path}/../lamp.png")

  end

  def start_udp_server
#    weburl = web_view(:layout => {:expand =>  [:width, :height]}, :url => "http://www.ruby-lang.org")
    # puts "Starting UDP server..."

    s = UDPSocket.new
    s.bind('0.0.0.0', 12345)

    begin
      body, sender = s.recvfrom(1024)
      self.pi_ip = sender[3]
      #puts body
      #data = Marshal.load(body)
    rescue Exception
      s.close
    end
  end

  def ping_udp_server
    body = "reply_port=12345,content=Hello"

    # puts "Querying UDP server..."
    s = UDPSocket.new
    s.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
    #s.send(Marshal.dump(body), 0, '<broadcast>', SERVER_LISTEN_PORT)
    s.send(body, 0, '<broadcast>', SERVER_LISTEN_PORT)
    s.close

  end

  def switch_lamp!()
    begin

      # puts "Querying http server..."
      uri = URI.parse("http://#{pi_ip}:4567/lamp/osx")
      
      response = Timeout::timeout(10) do
        http = Net::HTTP.new(uri.host, uri.port)
        http.request(Net::HTTP::Get.new(uri.request_uri))
      end

    rescue Exception => ex
      # puts ex.message
      msg!
    end
  end

  def reset_lamp!()
    begin

      # puts "Querying http server..."
      uri = URI.parse("http://#{pi_ip}:4567/lamp/led/reset")
      
      response = Timeout::timeout(10) do
        http = Net::HTTP.new(uri.host, uri.port)
        http.request(Net::HTTP::Get.new(uri.request_uri))
      end

    rescue Exception => ex
      msg!
    end
  end

  def check_processes
    @prcs.each do |prc|
      if active_prc = @system_events.processes.find { |p| p.name == prc[:name]}
        if ringing? active_prc, prc[:capture]
          unless prc[:ringing]
            prc[:ringing] = true 
            switch_lamp! if udp_server?
          end
        else
          prc[:ringing] = false
        end
      end
    end
  end

  def check_for_updates
    begin

      # puts "Querying http server..."
      uri = URI.parse("http://#{pi_ip}:4567/lamp/osx/version")
      
      response = Timeout::timeout(10) do
        http = Net::HTTP.new(uri.host, uri.port)
        http.request(Net::HTTP::Get.new(uri.request_uri))
      end

      version = response.body

      if version.to_i > CURRENT_VERSION
        # puts "Querying http server..."
        uri = URI.parse("http://#{pi_ip}:4567/lamp/osx/download")
        
        response = Timeout::timeout(10) do
          http = Net::HTTP.new(uri.host, uri.port)
          http.request(Net::HTTP::Get.new(uri.request_uri))
        end

        download_msg!(response.body)

      else
        up_to_date_msg!
      end

    rescue Exception => ex
      # puts ex.message
      msg!
    end
  end
  
  def ringing?(current_prc, capture)
    if capture
      current_prc.windows.any? {|w| w.name =~ capture}
    else
      current_prc.windows.any? {|w| w.name.nil?}
    end
  end
  
  def on_tick(timer)
    unless @running
      Thread.new do
        @running = true
        check_processes()
        @running = false
      end
    end
  end

  def assistive_device_enabled?
    msg =<<-eomsg
Your system is not properly configured to run this script.
Please select the 'Enable access for assistive devices" checkbox
and trigger the script again to proceed.
    eomsg
    
    if @system_events.UIElementsEnabled
      return true
    else
      system_preference = SBApplication.applicationWithBundleIdentifier("com.apple.systempreferences")
      system_preference.activate
      ua = system_preference.panes.find { |p| p.name =~ @ua}
      system_preference.setCurrentPane(ua) if ua
      alert :message => msg, :icon => image(:file => "#{lib_path}/../lamp.png")
#      alert :message => msg, :icon => image(:file => "#{lib_path}/../resources/lamp.png")
      return false
    end

  end

  # quit menu item
  def on_quit(menu)
    #@xtension.quit
    NSApp.terminate self
  end

  # This is commented out, so the minimize menu item is disabled
  #def on_minimize(menu)
  #end

  # window/zoom
  def on_zoom(menu)
  end

  # window/bring_all_to_front
  def on_bring_all_to_front(menu)
  end
end

Lamp.new.start


