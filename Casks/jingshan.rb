cask "jingshan" do
  version "0.7.0"
  sha256 "851523a9a5d2af561aa66436d74e645ad74eea3c7af1aa6fe943726aa7953f05"

  url "https://github.com/Ks-Ht/jingshan/releases/download/v#{version}/Jingshan-#{version}.zip"
  name "净山"
  name "Jingshan"
  desc "清理与系统监控工具"
  homepage "https://github.com/Ks-Ht/jingshan"

  depends_on macos: :sonoma

  app "净山.app"

  zap trash: [
    "~/Library/Application Support/Jingshan",
    "~/Library/Logs/Jingshan",
    "~/Library/Preferences/net.kongshan.jingshan.plist",
  ]

  caveats <<~EOS
    净山目前是 ad-hoc 本机签名（没有 Apple Developer ID，未经苹果公证）。
    如果安装时没有加 --no-quarantine，首次启动会被 Gatekeeper 拦截，
    需要在 Finder 里右键点击 净山.app → 打开，或执行：
      xattr -cr /Applications/净山.app

    净山需要「完全磁盘访问权限」才能扫描缓存等位置，首次运行会引导前往
    系统设置 → 隐私与安全性 → 完全磁盘访问权限 手动开启。
  EOS
end
