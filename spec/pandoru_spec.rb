RSpec.describe Pandoru do
  it "has a version number" do
    expect(Pandoru::VERSION).not_to be nil
  end

  it "loads successfully" do
    expect { require 'pandoru' }.not_to raise_error
  end
end
