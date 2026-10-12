class Example < Formula
  desc "Fixture for the homebrew render action"
  homepage "https://github.com/muleyuck/github-actions"
  version "1.2.3"
  license "MIT"

  on_macos do
    on_arm do
      url "https://example.com/example-#{version}-arm.tar.xz"
      sha256 "109b8f5ac24f1ed8e7ebade1e5a345dbd5ede5509e62c75b0e70bd03299cfad0"
    end
    on_intel do
      url "https://example.com/example-#{version}-intel.tar.xz"
      sha256 "daa372666487804fbbf3d0a33d28bff1e42811103b9d6c00f9c4a47c7022a0b0"
    end
  end

  def install
    bin.install "example"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/example --version")
  end
end
