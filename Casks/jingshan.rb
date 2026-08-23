cask "jingshan" do
  version "0.9.1"
  sha256 "226c625938656dbbed51b21ae88101c3598a8bfa07e65d2169b64b212b94b580"

  url "https://github.com/kongshan-0924/jingshan/releases/download/v#{version}/Jingshan-#{version}.zip"
  name "净山"
  name "Jingshan"
  desc "清理与系统监控工具"
  homepage "https://github.com/kongshan-0924/jingshan"

  depends_on macos: :sonoma

  app "净山.app"

  postflight do
    system_command "/usr/bin/xattr", args: ["-cr", "#{appdir}/净山.app"]
  end

  zap trash: [
    "~/Library/Application Support/Jingshan",
    "~/Library/Logs/Jingshan",
    "~/Library/Preferences/net.kongshan.jingshan.plist",
  ]

  caveats <<~EOS
    净山目前是 ad-hoc 本机签名（没有 Apple Developer ID，未经苹果公证）。
    安装时已自动清除隔离属性（quarantine），可以直接双击打开。

    如果仍然被 Gatekeeper 拦截（提示"无法打开，因为无法验证开发者"），
    可以在 Finder 里右键点击 净山.app → 打开，或手动执行：
      xattr -cr /Applications/净山.app

    净山需要「完全磁盘访问权限」才能扫描缓存等位置，首次运行会引导前往
    系统设置 → 隐私与安全性 → 完全磁盘访问权限 手动开启。
  EOS
end
