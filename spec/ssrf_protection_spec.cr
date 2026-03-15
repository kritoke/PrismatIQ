require "./spec_helper"

describe PrismatIQ::Utils::IPValidator do
  describe ".private_ipv4?" do
    it "returns true for 10.0.0.0/8 range" do
      PrismatIQ::Utils::IPValidator.private_ipv4?("10.0.0.1").should be_true
      PrismatIQ::Utils::IPValidator.private_ipv4?("10.255.255.255").should be_true
    end

    it "returns true for 172.16.0.0/12 range" do
      PrismatIQ::Utils::IPValidator.private_ipv4?("172.16.0.1").should be_true
      PrismatIQ::Utils::IPValidator.private_ipv4?("172.31.255.255").should be_true
    end

    it "returns true for 192.168.0.0/16 range" do
      PrismatIQ::Utils::IPValidator.private_ipv4?("192.168.0.1").should be_true
      PrismatIQ::Utils::IPValidator.private_ipv4?("192.168.255.255").should be_true
    end

    it "returns true for 127.0.0.0/8 loopback range" do
      PrismatIQ::Utils::IPValidator.private_ipv4?("127.0.0.1").should be_true
      PrismatIQ::Utils::IPValidator.private_ipv4?("127.255.255.255").should be_true
    end

    it "returns true for 169.254.0.0/16 link-local range" do
      PrismatIQ::Utils::IPValidator.private_ipv4?("169.254.0.1").should be_true
      PrismatIQ::Utils::IPValidator.private_ipv4?("169.254.169.254").should be_true
    end

    it "returns true for 0.0.0.0/8 range" do
      PrismatIQ::Utils::IPValidator.private_ipv4?("0.0.0.0").should be_true
      PrismatIQ::Utils::IPValidator.private_ipv4?("0.255.255.255").should be_true
    end

    it "returns false for public IP addresses" do
      PrismatIQ::Utils::IPValidator.private_ipv4?("8.8.8.8").should be_false
      PrismatIQ::Utils::IPValidator.private_ipv4?("1.1.1.1").should be_false
      PrismatIQ::Utils::IPValidator.private_ipv4?("93.184.216.34").should be_false
    end
  end

  describe ".private_ipv6?" do
    it "returns true for ::1 loopback" do
      PrismatIQ::Utils::IPValidator.private_ipv6?("::1").should be_true
    end

    it "returns true for fc00::/7 ULA range" do
      PrismatIQ::Utils::IPValidator.private_ipv6?("fc00::1").should be_true
      PrismatIQ::Utils::IPValidator.private_ipv6?("fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff").should be_true
    end

    it "returns true for fe80::/10 link-local range" do
      PrismatIQ::Utils::IPValidator.private_ipv6?("fe80::1").should be_true
      PrismatIQ::Utils::IPValidator.private_ipv6?("febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff").should be_true
    end

    it "returns false for public IPv6 addresses" do
      PrismatIQ::Utils::IPValidator.private_ipv6?("2001:4860:4860::8888").should be_false
      PrismatIQ::Utils::IPValidator.private_ipv6?("2606:4700:4700::1111").should be_false
    end
  end
end

describe PrismatIQ::Error do
  describe ".ssrf_blocked" do
    it "creates SSRF blocked error with context" do
      error = PrismatIQ::Error.ssrf_blocked("http://127.0.0.1/admin", "127.0.0.1", "loopback")
      error.type.should eq(PrismatIQ::ErrorType::SSRFBlocked)
      error.message.should contain("SSRF blocked")
      error.message.should contain("loopback")
      error.context.try(&.[]("url")).should eq("http://127.0.0.1/admin")
      error.context.try(&.[]("ip")).should eq("127.0.0.1")
      error.context.try(&.[]("reason")).should eq("loopback")
    end
  end
end

describe PrismatIQ::SSRFError do
  it "creates exception with URL, IP, and reason" do
    error = PrismatIQ::SSRFError.new("http://example.com", "192.168.1.1", "private_address")
    error.url.should eq("http://example.com")
    error.ip.should eq("192.168.1.1")
    error.reason.should eq("private_address")
    error.message.should contain("SSRF blocked")
  end
end
