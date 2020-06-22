require "./spec_helper"

describe Repeater::RequestData do
  it "parses request" do
    message = <<-EOF
      {
        "method": "GET",
        "url": "https://www.google.com",
        "headers": {
          "User-Agent": ["NexPloit On-Prem Agent"]
        }
      }
      EOF

    request = Repeater::RequestData.from_json(message)
    request.method.should eq("GET")
    request.url.should eq("https://www.google.com")
  end

  it "parses request and adds headers" do

    ENV["EXTRA_HEADERS"] = <<-EOF
      {
        "my_header": "1234"
      }
      EOF

    message = <<-EOF
      {
        "method": "GET",
        "url": "https://www.google.com",
        "headers": {
          "User-Agent": ["NexPloit On-Prem Agent"]
        }
      }
      EOF

    request = Repeater::RequestData.from_json(message)
    request.method.should eq("GET")
    request.url.should eq("https://www.google.com")
    request.headers["my_header"].first.should eq("1234")
  end
end
