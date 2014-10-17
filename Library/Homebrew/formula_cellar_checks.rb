module FormulaCellarChecks
  def check_PATH bin
    # warn the user if stuff was installed outside of their PATH
    return unless bin.directory?
    return unless bin.children.length > 0

    prefix_bin = (HOMEBREW_PREFIX/bin.basename)
    return unless prefix_bin.directory?

    prefix_bin = prefix_bin.realpath
    return if ORIGINAL_PATHS.include? prefix_bin

    <<-EOS.undent
      #{prefix_bin} is not in your PATH
      You can amend this by altering your ~/.bashrc file
    EOS
  end

  def check_manpages
    # Check for man pages that aren't in share/man
    return unless (f.prefix+'man').directory?

    <<-EOS.undent
      A top-level "man" directory was found
      Homebrew requires that man pages live under share.
      This can often be fixed by passing "--mandir=\#{man}" to configure.
    EOS
  end

  def check_infopages
    # Check for info pages that aren't in share/info
    return unless (f.prefix+'info').directory?

    <<-EOS.undent
      A top-level "info" directory was found
      Homebrew suggests that info pages live under share.
      This can often be fixed by passing "--infodir=\#{info}" to configure.
    EOS
  end

  def check_jars
    return unless f.lib.directory?
    jars = f.lib.children.select { |g| g.extname == ".jar" }
    return if jars.empty?

    <<-EOS.undent
      JARs were installed to "#{f.lib}"
      Installing JARs to "lib" can cause conflicts between packages.
      For Java software, it is typically better for the formula to
      install to "libexec" and then symlink or wrap binaries into "bin".
      See "activemq", "jruby", etc. for examples.
      The offending files are:
        #{jars * "\n        "}
    EOS
  end

  def check_non_libraries
    return unless f.lib.directory?

    valid_extensions = %w(.a .dylib .framework .jnilib .la .o .so
                          .jar .prl .pm .sh)
    non_libraries = f.lib.children.select do |g|
      next if g.directory?
      not valid_extensions.include? g.extname
    end
    return if non_libraries.empty?

    <<-EOS.undent
      Non-libraries were installed to "#{f.lib}"
      Installing non-libraries to "lib" is discouraged.
      The offending files are:
        #{non_libraries * "\n        "}
    EOS
  end

  def check_non_executables bin
    return unless bin.directory?

    non_exes = bin.children.select { |g| g.directory? or not g.executable? }
    return if non_exes.empty?

    <<-EOS.undent
      Non-executables were installed to "#{bin}"
      The offending files are:
        #{non_exes * "\n        "}
    EOS
  end

  def check_generic_executables bin
    return unless bin.directory?
    generic_names = %w[run service start stop]
    generics = bin.children.select { |g| generic_names.include? g.basename.to_s }
    return if generics.empty?

    <<-EOS.undent
      Generic binaries were installed to "#{bin}"
      Binaries with generic names are likely to conflict with other software,
      and suggest that this software should be installed to "libexec" and then
      symlinked as needed.

      The offending files are:
        #{generics * "\n        "}
    EOS
  end

  def check_shadowed_headers
    return if f.name == "libtool" || f.name == "subversion"
    return if f.keg_only? || !f.include.directory?

    files  = relative_glob(f.include, "**/*.h")
    files &= relative_glob("#{MacOS.sdk_path}/usr/include", "**/*.h")
    files.map! { |p| File.join(f.include, p) }

    return if files.empty?

    <<-EOS.undent
      Header files that shadow system header files were installed to "#{f.include}"
      The offending files are:
        #{files * "\n        "}
    EOS
  end

  def check_easy_install_pth lib
    pth_found = Dir["#{lib}/python{2.7,3.4}/site-packages/easy-install.pth"].map { |f| File.dirname(f) }
    return if pth_found.empty?

    <<-EOS.undent
      easy-install.pth files were found
      These .pth files are likely to cause link conflicts. Please invoke
      setup.py with options
        --single-version-externally-managed --record=install.txt
      The offending files are
        #{pth_found * "\n        "}
    EOS
  end

  def audit_installed
    audit_check_output(check_manpages)
    audit_check_output(check_infopages)
    audit_check_output(check_jars)
    audit_check_output(check_non_libraries)
    audit_check_output(check_non_executables(f.bin))
    audit_check_output(check_generic_executables(f.bin))
    audit_check_output(check_non_executables(f.sbin))
    audit_check_output(check_generic_executables(f.sbin))
    audit_check_output(check_shadowed_headers)
    audit_check_output(check_easy_install_pth(f.lib))
  end

  private

  def relative_glob(dir, pattern)
    return [] unless Dir.exist? dir
    Dir.chdir(dir) { Dir[pattern] }
  end
end
