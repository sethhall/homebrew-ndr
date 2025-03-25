class ZeekFull < Formula
  desc "Zeek is a powerful network analysis framework that is much different from the typical IDS you may know."
  homepage "https://www.zeek.org"
  url "https://github.com/zeek/zeek/releases/download/v7.1.1/zeek-7.1.1.tar.gz"
  sha256 "f7974900c44c322b8bee5f502d683b3dcc478687b5ac75b23e2f8a049457d683"
  license "NOASSERTION"

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "flex" => :build
  depends_on "swig" => :build
  depends_on "c-ares"
  depends_on "libmaxminddb"
  depends_on macos: :mojave
  depends_on "openssl@3"
  depends_on "python@3.13"
  depends_on "libnode@22"
  depends_on "jemalloc"

  uses_from_macos "krb5"
  uses_from_macos "libpcap"
  uses_from_macos "libxcrypt"
  uses_from_macos "zlib"

  # Additional dependency
  # resource "" do
  #   url ""
  #   sha256 ""
  # end

  def install
    # Remove SDK paths from zeek-config. This breaks usage with other SDKs.
    # https://github.com/Homebrew/homebrew-core/pull/74932
    inreplace "cmake_templates/zeek-config.in" do |s|
      s.gsub! "@ZEEK_CONFIG_PCAP_INCLUDE_DIR@", ""
      s.gsub! "@ZEEK_CONFIG_ZLIB_INCLUDE_DIR@", ""
    end

    # Avoid references to the Homebrew shims directory
    inreplace "auxil/spicy/hilti/toolchain/src/config.cc.in", "${CMAKE_CXX_COMPILER}", ENV.cxx

    system "cmake", "-S", ".", "-B", "build",
                    "-DBROKER_DISABLE_TESTS=on",
                    "-DINSTALL_AUX_TOOLS=on",
                    "-DINSTALL_ZEEKCTL=on",
                    "-DUSE_GEOIP=on",
                    "-DCARES_ROOT_DIR=#{Formula["c-ares"].opt_prefix}",
                    "-DCARES_LIBRARIES=#{Formula["c-ares"].opt_lib/shared_library("libcares")}",
                    "-DLibMMDB_ROOT_DIR=#{Formula["libmaxminddb"].opt_prefix}",
                    "-DOPENSSL_ROOT_DIR=#{Formula["openssl@3"].opt_prefix}",
                    "-DNODEJS_ROOT_DIR=#{Formula["libnode@22"].opt_prefix}",
                    "-DENABLE_JEMALLOC=true",
                    "-DENABLE_ZEEK_UNIT_TESTS=false",
                    "-DBROKER_DISABLE_TESTS=true",
                    "-DBROKER_DISABLE_DOC_EXAMPLES=true",
                    "-DINSTALL_BTEST=false",
                    "-DINSTALL_BTEST_PCAPS=false",
                    "-DJEMALLOC_ROOT_DIR=#{Formula["jemalloc"].opt_prefix}",
                    "-DPYTHON_EXECUTABLE=#{which("python3.13")}",
                    "-DFLEX_EXECUTABLE=#{Formula["flex"].opt_bin}/flex",
                    "-DBISON_EXECUTABLE=#{Formula["bison"].opt_bin}/bison",
                    "-DZEEK_ETC_INSTALL_DIR=#{etc}",
                    "-DZEEK_LOCAL_STATE_DIR=#{var}",
                    *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    assert_match "version #{version}", shell_output("#{bin}/zeek --version")
    assert_match "ARP packet analyzer", shell_output("#{bin}/zeek --print-plugins")
    system bin/"zeek", "-C", "-r", test_fixtures("test.pcap")
    assert_path_exists testpath/"conn.log"
    refute_empty (testpath/"conn.log").read
    assert_path_exists testpath/"http.log"
    refute_empty (testpath/"http.log").read
    # For bottling MacOS SDK paths must not be part of the public include directories, see zeek/zeek#1468.
    refute_includes shell_output("#{bin}/zeek-config --include_dir").chomp, "MacOSX"
  end
end
