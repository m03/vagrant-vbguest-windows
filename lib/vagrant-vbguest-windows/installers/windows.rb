module VagrantVbguestWindows
  # A basic Installer implementation for unknown
  # Windows based systems.
  class Windows < ::VagrantVbguest::Installers::Base
    VERSION_PATTERN = Regexp::new('^(\d+\.\d+.\d+)')

    # Matches if the operating system name prints "Windows"
    # Raises an Error if this class is beeing subclassed but
    # this method was not overridden. This is considered an
    # error because, subclassed Installers usually indicate
    # a more specific distributen like 'ubuntu' or 'arch' and
    # therefore should do a more specific check.
    def self.match?(vm)
      raise Error, :_key => :do_not_inherit_match_method if self != Windows
      return VagrantPlugins::GuestWindows::Guest.new().detect?(vm)
    end

    # Since we don't have `/etc/os-release` under Windows guests,
    # replicate the portion of the structure that gets used by
    # vagrant-vbguest, so that os_release functions similar to
    # the way it does in the Linux installer.
    # The result is cached on a per-vm basis.
    #
    # @return [Hash|nil] The os-release configuration as Hash, or `nil if file is not present or not parsable.
    def self.os_release(vm)
      @@os_release_info ||= Hash.new
      osr = {
        :ID          => String.new,
        :PRETTY_NAME => String.new
      }
      release_pattern = Regexp::new('(?<prefix>win).*?(?<version>\d+)\s+(?<release>r\d+)?')
      cmd = <<-SHELL
      $Caption = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty Caption
      Return $Caption
      SHELL
      begin
        communicate.sudo(cmd, :error_check => false) do |type, data|
          osr[:PRETTY_NAME] = data.strip unless data.empty?
        end
      rescue => error
        vm.env.ui.warn(error.message)
        return nil
      end
      if osr[:PRETTY_NAME].downcase.match(release_pattern)
        osr[:ID] = "#{$~[:prefix]}#{$~[:version]}#{$~[:release]}"
      end
      osr[:VERSION_ID] = osr[:ID]
      @@os_release_info[vm_id(vm)] = osr
      return osr
    end

    def os_release
      self.class.os_release(vm)
    end

    # Determine the temporary directory where the ISO file
    # will be uploaded to. Defaults to `$($Env:Temp)`.
    #
    # @param opts [Hash] Optional options Hash which might get passed to {Vagrant::Communication::WinRM#execute} and friends
    # @yield [type, data] Takes a Block like {Vagrant::Communication::Base#execute} for realtime output of the command being executed
    # @yieldparam [String] type Type of the output, `:stdout`, `:stderr`, etc.
    # @yieldparam [String] data Data for the given output.
    def tmp_dir
      return @tmp_dir if @tmp_dir
      env_tmp = '$($Env:Temp)'
      cmd = <<-SHELL
      Get-Item -Path #{env_tmp} | Select-Object -ExpandProperty FullName
      SHELL
      communicate.sudo(cmd, :error_check => false) do |type, data|
        @tmp_dir = data.strip || env_tmp
      end
      return @tmp_dir
    end

    # The temporary path where to upload the iso file to.
    # Configurable via `config.vbguest.iso_upload_path`.
    # Defaults the temp path to `$($Env:Temp)\\VBoxGuestAdditions.iso`
    # for all Windows based systems.
    def tmp_path
      options[:iso_upload_path] || "#{tmp_dir}\\VBoxGuestAdditions.iso"
    end

    # Mount point for the iso file.
    # PowerShell Mount-DiskImage auto-assigns a mount point,
    # so ignore `config.vbguest.iso_mount_point` and use @mount_point instead.
    def mount_point
      @mount_point ||= options[:iso_mount_point]
      return @mount_point
    end

    # The absolute path to the GuestAdditions installer.
    # The iso file has to be mounted on +mount_point+.
    def installer
      @installer ||= File.join(mount_point, 'VBoxWindowsAdditions.exe')
    end

    # The arguments string, which gets passed to the installer executable
    def windows_installer_arguments
#      @windows_installer_arguments ||= Array(options[:windows_installer_arguments]).join " "
      @windows_installer_arguments ||= '/S'
    end

    # Go through the installation process.
    #
    # @param opts [Hash] Optional options Hash which might get passed to {Vagrant::Communication::WinRM#execute} and friends
    # @yield [type, data] Takes a Block like {Vagrant::Communication::Base#execute} for realtime output of the command being executed
    # @yieldparam [String] type Type of the output, `:stdout`, `:stderr`, etc.
    # @yieldparam [String] data Data for the given output.
    def install(opts=nil, &block)
      upload(iso_file)
      mount_iso(opts, &block)
      execute_certutil(opts, &block)
      execute_installer(opts, &block)
      unmount_iso(opts, &block) unless options[:no_cleanup]
    end

    # @param opts [Hash] Optional options Hash wich meight get passed to {Vagrant::Communication::SSH#execute} and firends
    # @yield [type, data] Takes a Block like {Vagrant::Communication::Base#execute} for realtime output of the command being executed
    # @yieldparam [String] type Type of the output, `:stdout`, `:stderr`, etc.
    # @yieldparam [String] data Data for the given outputervice
    def rebuild(opts=nil, &block)
      install(opts, &block)
    end

    # Mount the GuestAdditions iso file on Windows systems
    # that have native PowerShell 4 or newer.
    # Mounts the given uploaded file from +tmp_path+ on +mount_point+.
    #
    # @param opts [Hash] Optional options Hash wich meight get passed to {Vagrant::Communication::SSH#execute} and firends
    # @yield [type, data] Takes a Block like {Vagrant::Communication::Base#execute} for realtime output of the command being executed
    # @yieldparam [String] type Type of the output, `:stdout`, `:stderr`, etc.
    # @yieldparam [String] data Data for the given output.
    def mount_iso(opts=nil, &block)
      cmd = <<-SHELL
      $CimInstance = Mount-DiskImage -ImagePath "#{tmp_path}" -PassThru
      $DriveLetter = $CimInstance | Get-Volume | Select-Object -ExpandProperty DriveLetter
      Write-Output "$($DriveLetter):/";
      SHELL
      communicate.sudo(cmd, opts) do |type, data|
        block
        @mount_point = data.strip unless data.empty?
      end
      env.ui.info(I18n.t("vagrant_vbguest_windows.mounting_iso", :mount_point => mount_point))
    end

    # Un-mounting the GuestAdditions iso file on Windows systems
    # that have native PowerShell 4 or newer.
    # Unmounts the +tmp_path+.
    #
    # @param opts [Hash] Optional options Hash wich meight get passed to {Vagrant::Communication::SSH#execute} and firends
    # @yield [type, data] Takes a Block like {Vagrant::Communication::Base#execute} for realtime output of the command being executed
    # @yieldparam [String] type Type of the output, `:stdout`, `:stderr`, etc.
    # @yieldparam [String] data Data for the given output.
    def unmount_iso(opts=nil, &block)
      env.ui.info(I18n.t("vagrant_vbguest_windows.unmounting_iso", :mount_point => mount_point))
      opts = {:error_check => false}.merge(opts || {})
      communicate.sudo("Dismount-DiskImage -ImagePath \"#{tmp_path}\"", opts, &block)
    end

    # This overrides {VagrantVbguest::Installers::Base#guest_version}
    # to also query the `VBoxService` on the host system (if available)
    # for it's version.
    # In some scenarios the results of the VirtualBox driver and the
    # additions installed on the host may differ. If this happens, we
    # assume, that the host binaries are right and yield a warning message.
    #
    # @return [String] The version code of the VirtualBox Guest Additions
    #                  available on the guest, or `nil` if none installed.
    def guest_version(reload=false)
      return @guest_version if @guest_version && !reload
      driver_version = super.to_s[VERSION_PATTERN, 1]

      communicate.sudo('VBoxService --version', :error_check => false) do |type, data|
        service_version = data.to_s[VERSION_PATTERN, 1]
        if service_version
          if driver_version != service_version
            @env.ui.warn(I18n.t("vagrant_vbguest.guest_version_reports_differ", :driver => driver_version, :service => service_version))
          end
          @guest_version = service_version
        end
      end
      @guest_version
    end

    # @param opts [Hash] Optional options Hash wich meight get passed to {Vagrant::Communication::SSH#execute} and firends
    # @yield [type, data] Takes a Block like {Vagrant::Communication::Base#execute} for realtime output of the command being executed
    # @yieldparam [String] type Type of the output, `:stdout`, `:stderr`, etc.
    # @yieldparam [String] data Data for the given output.
    def start(opts=nil, &block)
      opts = {:error_check => false}.merge(opts || {})
      cmd = <<-SHELL
      $VBoxService = Get-Service -Name VBoxService | Select-Object -First 1
      Start-Service -Name $Service.Name
      SHELL
      communicate.sudo(cmd, opts, &block)
    end

    # @param opts [Hash] Optional options Hash which might get passed to {Vagrant::Communication::WinRM#execute} and friends
    # @yield [type, data] Takes a Block like {Vagrant::Communication::Base#execute} for realtime output of the command being executed
    # @yieldparam [String] type Type of the output, `:stdout`, `:stderr`, etc.
    # @yieldparam [String] data Data for the given output.
    def running?(opts=nil, &block)
      cmd = <<-SHELL
      $VBoxService = Get-Service -Name VBoxService | Select-Object -First 1
      if ("$($VBoxService.Status)".StartsWith('Run')) { Exit 0 } Exit 1
      SHELL
      opts = {:sudo => true}.merge(opts || {})
      communicate.test(cmd, opts, &block)
    end

    # Helper to ensure that the certificates are in place
    # so that the installer doesn't prompt for user input.
    #
    # @param opts [Hash] Optional options Hash which might get passed to {Vagrant::Communication::SSH#execute} and friends
    # @yield [type, data] Takes a Block like {Vagrant::Communication::Base#execute} for realtime output of the command being executed
    # @yieldparam [String] type Type of the output, `:stdout`, `:stderr`, etc.
    # @yieldparam [String] data Data for the given output.
    def execute_certutil(opts=nil, &block)
      cmd = <<-SHELL
      $CertDir = Join-Path -Path '#{mount_point}' -ChildPath 'cert'
      $UtilPath = Join-Path -Path $CertDir -ChildPath 'VBoxCertUtil.exe'
      $Certificates = @(Get-ChildItem -Path $CertDir -Filter *.cer | Foreach-Object { $_.FullName })
      $Certificates | ForEach-Object { Start-Process -FilePath $UtilPath -ArgumentList "add-trusted-publisher $($_) --root $($_)" -Wait }
      SHELL
      opts = {:error_check => false}.merge(opts || {})
      communicate.sudo(cmd, opts, &block)
    end

    # A generic helper method to execute the installer.
    # This also yields a installation warning to the user, and an error
    # warning in the event that the installer returns a non-zero exit status.
    #
    # @param opts [Hash] Optional options Hash which might get passed to {Vagrant::Communication::SSH#execute} and friends
    # @yield [type, data] Takes a Block like {Vagrant::Communication::Base#execute} for realtime output of the command being executed
    # @yieldparam [String] type Type of the output, `:stdout`, `:stderr`, etc.
    # @yieldparam [String] data Data for the given output.
    def execute_installer(opts=nil, &block)
      yield_installation_warning(installer)
      cmd = <<-SHELL
      $ExitCode = (Start-Process -FilePath '#{installer}' -ArgumentList '#{windows_installer_arguments}' -Wait -PassThru).ExitCode
      Start-Sleep -Seconds 60
      Return $ExitCode
      SHELL
      opts = {:error_check => false}.merge(opts || {})
      communicate.sudo(cmd, opts) do |type, data|
        block
        yield_installation_error_warning(installer) unless data.strip.to_i == 0
      end
    end

    # Determines the version of the GuestAdditions installer in use.
    #
    # @return [String] The version code of the GuestAdditions installer
    def installer_version(path_to_installer)
      version = nil
      cmd = <<-SHELL
      $Installer = Get-ItemProperty -Path "#{installer}"
      $Installer.VersionInfo | Select-Object -ExpandProperty FileVersion
      SHELL
      communicate.sudo(cmd, :error_check => false) do |type, data|
        version = data.to_s[VERSION_PATTERN, 1]
      end
      version
    end
  end
end
# Register the Windows class with VagrantVbguest.
VagrantVbguest::Installer.register(VagrantVbguestWindows::Windows, 6)
