# frozen_string_literal: true

module Solargraph
  class ComplexType
    # Methods for accessing type data.
    #
    module TypeMethods
      # @return [String]
      attr_reader :name

      # @return [String]
      attr_reader :substring

      # @return [String]
      attr_reader :tag

      # @return [Array<ComplexType>]
      attr_reader :subtypes

      # @return [Boolean]
      def duck_type?
        @duck_type ||= name.start_with?('#')
      end

      # @return [Boolean]
      def nil_type?
        @nil_type ||= (name.downcase == 'nil')
      end

      # @return [Boolean]
      def parameters?
        !substring.empty?
      end

      def void?
        name == 'void'
      end

      def defined?
        !undefined?
      end

      def undefined?
        name == 'undefined'
      end

      # @return [Boolean]
      def list_parameters?
        substring.start_with?('<')
      end

      # @return [Boolean]
      def fixed_parameters?
        substring.start_with?('(')
      end

      # @return [Boolean]
      def hash_parameters?
        substring.start_with?('{')
      end

      # @return [Array<ComplexType>]
      def value_types
        @subtypes
      end

      # @return [Array<ComplexType>]
      def key_types
        @key_types
      end

      # @return [String]
      def namespace
        @namespace ||= 'Object' if duck_type?
        @namespace ||= 'NilClass' if nil_type?
        @namespace ||= (name == 'Class' || name == 'Module') && !subtypes.empty? ? subtypes.first.name : name
      end

      # @return [Symbol] :class or :instance
      def scope
        @scope ||= :instance if duck_type? || nil_type?
        @scope ||= (name == 'Class' || name == 'Module') && !subtypes.empty? ? :class : :instance
      end

      def == other
        return false unless self.class == other.class
        tag == other.tag
      end

      def rooted?
        @rooted
      end

      # Generate a ComplexType that fully qualifies this type's namespaces.
      #
      # @param api_map [ApiMap] The ApiMap that performs qualification
      # @param context [String] The namespace from which to resolve names
      # @return [ComplexType] The generated ComplexType
      def qualify api_map, context = ''
        return ComplexType.new([self]) if duck_type? || void? || undefined?
        recon = (rooted? ? '' : context)
        fqns = api_map.qualify(name, recon)
        if fqns.nil?
          return UniqueType::BOOLEAN if tag == 'Boolean'
          return UniqueType::UNDEFINED
        end
        fqns = "::#{fqns}" # Ensure the resulting complex type is rooted
        ltypes = key_types.map do |t|
          t.qualify api_map, context
        end
        rtypes = value_types.map do |t|
          t.qualify api_map, context
        end
        if list_parameters?
          Solargraph::ComplexType.parse("#{fqns}<#{rtypes.map(&:tag).join(', ')}>").first
        elsif fixed_parameters?
          Solargraph::ComplexType.parse("#{fqns}(#{rtypes.map(&:tag).join(', ')})").first
        elsif hash_parameters?
          Solargraph::ComplexType.parse("#{fqns}{#{ltypes.map(&:tag).join(', ')} => #{rtypes.map(&:tag).join(', ')}}").first
        else
          Solargraph::ComplexType.parse(fqns).first
        end
      end
    end
  end
end
