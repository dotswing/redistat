require 'redistat/finder/date_set'

module Redistat
  class Finder
    include Database
    
    class << self
      def find(*args)
        new.find(*args)
      end
      
      def scope(scope)
        new.scope(scope)
      end
      
      def label(label)
        new.label(label)
      end
      
      def dates(from, till)
        new.dates(from, till)
      end
      alias :date :dates
      
      def from(date)
        new.from(date)
      end
      
      def till(date)
        new.till(date)
      end
      alias :untill :till
      
      def depth(unit)
        new.depth(unit)
      end
      
      def interval(unit)
        new.interval(unit)
      end
    end
    
    attr_reader :options
    
    def initialize(opts = {})
      set_options(opts)
    end
    
    def options
      @options ||= {}
    end
    
    def all(reload = false)
      @result = nil if reload
      @result ||= find
    end
    
    def total
      all.total
    end
    
    def each(&block)
      all.each(&block)
    end
    
    def map(&block)
      all.map(&block)
    end
    
    def each_with_index(&block)
      all.each_with_index(&block)
    end
    
    def parent
      @parent ||= self.class.new(options.merge(:label => options[:label].parent)) unless options[:label].nil?
    end
    
    def children
      build_key.children.map { |key|
        self.class.new(options.merge(:label => key.label.to_s))
      }
    end
    
    def connection_ref(ref)
      reset! if options[:connection_ref] != ref
      options[:connection_ref] = ref
      self
    end
    
    def scope(scope)
      reset! if !options[:scope].nil? && options[:scope].to_s != scope
      options[:scope] = Scope.new(scope)
      self
    end
    
    def label(label)
      reset! if options.has_key?(:label) && options[:label].to_s != label.to_s
      options[:label] = (!label.nil?) ? Label.new(label) : nil
      self
    end
    
    def dates(from, till)
      from(from).till(till)
    end
    alias :date :dates
    
    def from(date)
      reset! if options[:from] != date
      options[:from] = date
      self
    end
    
    def till(date)
      reset! if options[:till] != date
      options[:till] = date
      self
    end
    alias :until :till
    
    def depth(unit)
      reset! if options[:depth] != unit
      options[:depth] = unit
      self
    end
    
    def interval(unit)
      reset! if options[:interval] != unit
      options[:interval] = unit
      self
    end
    
    def find(opts = {})
      set_options(opts)
      raise InvalidOptions.new if !valid_options?
      if options[:interval].nil? || !options[:interval]
        find_by_magic
      else
        find_by_interval
      end
    end
    
    private
    
    def set_options(opts = {})
      opts = opts.clone
      opts.each do |key, value|
        self.send(key, opts.delete(key)) if self.respond_to?(key)
      end
      self.options.merge!(opts)
    end
    
    def find_by_interval
      raise InvalidOptions.new if !valid_options?
      key = build_key
      col = Collection.new(options)
      col.total = Result.new(options)
      build_date_sets.each do |set|
        set[:add].each do |date|
          result = Result.new
          result.date = Date.new(date).to_time
          db.hgetall("#{key.prefix}#{date}").each do |k, v|
            result[k] = v
            col.total.set_or_incr(k, v.to_i)
          end
          col << result
        end
      end
      col
    end
    
    def find_by_magic
      raise InvalidOptions.new if !valid_options?
      key = build_key
      col = Collection.new(options)
      col.total = Result.new(options)
      col << col.total
      build_date_sets.each do |set|
        sum = Result.new
        sum = summarize_add_keys(set[:add], key, sum)
        sum = summarize_rem_keys(set[:rem], key, sum)
        sum.each do |k, v|
          col.total.set_or_incr(k, v.to_i)
        end
      end
      col
    end

    def reset!
      @result = nil
      @parent = nil
    end
    
    def valid_options?
      return true if !options[:scope].blank? && !options[:label].blank? && !options[:from].blank? && !options[:till].blank?
      false
    end
    
    def build_date_sets
      Finder::DateSet.new(options[:from], options[:till], options[:depth], options[:interval])
    end
    
    def build_key
      Key.new(options[:scope], options[:label])
    end
    
    def summarize_add_keys(sets, key, sum)
      sets.each do |date|
        db.hgetall("#{key.prefix}#{date}").each do |k, v|
          sum.set_or_incr(k, v.to_i)
        end
      end
      sum
    end
    
    def summarize_rem_keys(sets, key, sum)
      sets.each do |date|
        db.hgetall("#{key.prefix}#{date}").each do |k, v|
          sum.set_or_incr(k, -v.to_i)
        end
      end
      sum
    end
    
    def db
      super(options[:connection_ref])
    end
    
  end
end