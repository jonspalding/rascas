require 'rubygems'
require 'nokogiri'

def Rascas(html, data = nil)
  data = {} if !data
  data.merge! yield if block_given?
  Rascas::Template.new(html).process(data)
end

class Rascas
  attr_reader :html
  
  def initialize(html)
    @html = html
  end

  def to_s
    @html.to_xhtml
  end

  def self.haml(haml, data = nil, &block)
    require 'haml'

    html = Haml::Engine.new(haml).render
    Rascas(html, data, &block)
  end

  class Template
    def initialize(html)
      if html.respond_to?(:read)
        html = html.read
      end
      @html = Nokogiri::HTML.fragment(html)
    end

    def process(hash)
      ::Rascas::Mapper::HashMapper.new(hash).map(@html)
      Rascas.new(@html)
    end

  end

  module Mapper

    def self.for(data_item)
      mapper_class = data_item.class.name + "Mapper"
      self.const_get( mapper_class ).new( data_item )
    rescue
      StringMapper.new(data_item.to_s)
    end

    class Mapper
      def initialize(val)
        @val = val
      end

      def map(elements_or_element)
        elements_or_element = [elements_or_element] unless (elements_or_element.respond_to? :length)        
        elements_or_element.each do |element|
          map_element element
        end
      end
    end

    class RascasMapper < Mapper
      def map_element(element)
        element.add_child @val.html
      end
    end

    class StringMapper < Mapper
      def map_element(element)
        element.content = @val
      end
    end

    class HashMapper < Mapper
      def map(elements)
        @val.each do |selector, data_item|
          if (selector == 'content' || selector == :content)
            StringMapper.new(data_item).map(elements)
            next
          end
          if (selector =~ /^@([^\s]+)/ || selector.is_a?(Symbol))
            attr = $1 || selector.to_s
            if elements.respond_to? :set_attribute
              elements.set_attribute attr, data_item
            else
              elements.attr attr, data_item
            end
            next
          end
          
          begin
            selected_elements = elements.search(selector)
          rescue Exception => e
            raise e, "Error using selector: #{selector}. #{e.message}"           
          end
          mapper = ::Rascas::Mapper.for(data_item)
          mapper.map(selected_elements)
        end
      end
    end

    class ArrayMapper < Mapper
      def map(elements)
        element_index = 0
        elements = elements.respond_to?(:length) ? elements : [elements]
        @val.each_with_index do |data, i|
          mapper = ::Rascas::Mapper.for(data)
          element = elements[element_index]
          if (i >= elements.length)
            element = element.dup
            elements.last.add_next_sibling element
          end
          mapper.map element
          element_index = (element_index == elements.length - 1 ) ? 0 : element_index + 1
        end

        if (elements.length > @val.length)
          elements[-1].following_siblings.remove
        end
      end
    end
  end
end
