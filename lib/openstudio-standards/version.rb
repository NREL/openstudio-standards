module OpenstudioStandards
  def self.git_revision
    cmd = 'git'
    exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
    ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
      exts.each do |ext|
        exe = "#{path}/#{cmd}#{ext}"
        if File.executable?(exe)
          revision = `"#{exe}" -C "#{__dir__}" rev-parse --short HEAD`
          return revision.strip!
        end
      end
    end
    return 'git-not-found-on-this-system'
  end
  #this should be updated to 0.2.12 when merging to 3.1.0
  #VERSION = '0.2.12.rc4'.freeze
  VERSION = '0.2.11'.freeze
end
