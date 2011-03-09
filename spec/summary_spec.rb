require "spec_helper"

describe Redistat::Summary do
  include Redistat::Database
  
  before(:each) do
    db.flushdb
    @scope = "PageViews"
    @label = "about_us"
    @date = Time.now
    @key = Redistat::Key.new(@scope, @label, @date, {:depth => :day})
    @stats = {"views" => 3, "visitors" => 2}
  end
  
  it "should update a single summary properly" do
    Redistat::Summary.update(@key, @stats, :hour)
    summary = db.hgetall(@key.to_s(:hour))
    summary.should have(2).items
    summary["views"].should == "3"
    summary["visitors"].should == "2"
    
    Redistat::Summary.update(@key, @stats, :hour)
    summary = db.hgetall(@key.to_s(:hour))
    summary.should have(2).items
    summary["views"].should == "6"
    summary["visitors"].should == "4"
    
    Redistat::Summary.update(@key, {"views" => -4, "visitors" => -3}, :hour)
    summary = db.hgetall(@key.to_s(:hour))
    summary.should have(2).items
    summary["views"].should == "2"
    summary["visitors"].should == "1"
  end
  
  it "should update all summaries properly" do
    Redistat::Summary.update_all(@key, @stats, :sec)
    [:year, :month, :day, :hour, :min, :sec, :usec].each do |depth|
      summary = db.hgetall(@key.to_s(depth))
      if depth != :usec
        summary.should have(2).items
        summary["views"].should == "3"
        summary["visitors"].should == "2"
      else
        summary.should have(0).items
      end
    end
  end
  
  it "should inject stats key grouping summaries" do
    hash = { "count/hello" => 3, "count/world"   => 7,
             "death/bomb"  => 4, "death/unicorn" => 3,
             :"od/sugar"   => 7, :"od/meth"      => 8 }
    res = Redistat::Summary.send(:inject_group_summaries, hash)
    res.should == { "count" => 10, "count/hello" => 3, "count/world"   => 7,
                    "death" => 7,  "death/bomb"  => 4, "death/unicorn" => 3,
                    "od"    => 15, :"od/sugar"   => 7, :"od/meth"      => 8 }
  end
  
  it "should properly store key group summaries" do
    stats = {"views" => 3, "visitors/eu" => 2, "visitors/us" => 4}
    Redistat::Summary.update_all(@key, stats, :hour)
    summary = db.hgetall(@key.to_s(:hour))
    summary.should have(4).items
    summary["views"].should == "3"
    summary["visitors"].should == "6"
    summary["visitors/eu"].should == "2"
    summary["visitors/us"].should == "4"
  end
  
  it "should not store key group summaries when option is disabled" do
    stats = {"views" => 3, "visitors/eu" => 2, "visitors/us" => 4}
    Redistat::Summary.update_all(@key, stats, :hour, nil, false)
    summary = db.hgetall(@key.to_s(:hour))
    summary.should have(3).items
    summary["views"].should == "3"
    summary["visitors/eu"].should == "2"
    summary["visitors/us"].should == "4"
  end
  
  it "should store label-based grouping enabled stats" do
    stats = {"views" => 3, "visitors/eu" => 2, "visitors/us" => 4}
    label = "views/about_us"
    key = Redistat::Key.new(@scope, label, @date)
    Redistat::Summary.update_all(key, stats, :hour)

    key.groups[0].label.to_s.should == "views/about_us"
    key.groups[1].label.to_s.should == "views"
    child1 = key.groups[0]
    parent = key.groups[1]
    
    label = "views/contact"
    key = Redistat::Key.new(@scope, label, @date)
    Redistat::Summary.update_all(key, stats, :hour)
    
    key.groups[0].label.to_s.should == "views/contact"
    key.groups[1].label.to_s.should == "views"
    child2 = key.groups[0]
    
    summary = db.hgetall(child1.to_s(:hour))
    summary["views"].should == "3"
    summary["visitors/eu"].should == "2"
    summary["visitors/us"].should == "4"
    
    summary = db.hgetall(child2.to_s(:hour))
    summary["views"].should == "3"
    summary["visitors/eu"].should == "2"
    summary["visitors/us"].should == "4"
    
    summary = db.hgetall(parent.to_s(:hour))
    summary["views"].should == "6"
    summary["visitors/eu"].should == "4"
    summary["visitors/us"].should == "8"
  end
  
end








