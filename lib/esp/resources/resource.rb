module ESP
  class Resource < ActiveResource::Base # :nodoc:
    self.site = ESP.site
    self.format = ActiveResource::Formats::JsonAPIFormat
    with_api_auth(ESP.access_key_id, ESP.secret_access_key)
    headers["Content-Type"] = format.mime_type

    self.collection_parser = ActiveResource::PaginatedCollection

    # List of predicate that can be used for searching
    PREDICATES = %w(m eq eq_any eq_all not_eq not_eq_any not_eq_all matches matches_any matches_all does_not_match does_not_match_any does_not_match_all lt lt_any lt_all lteq lteq_any lteq_all gt gt_any gt_all gteq gteq_any gteq_all in in_any in_all not_in not_in_any not_in_all cont cont_any cont_all not_cont not_cont_any not_cont_all start start_any start_all not_start not_start_any not_start_all end end_any end_all not_end not_end_any not_end_all true false present blank null not_null).freeze

    # Pass a json api compliant hash to the api.
    def serializable_hash(*)
      h = attributes.extract!('included')
      h['data'] = { 'type' => self.class.to_s.underscore.sub('esp/', '').pluralize,
                    'attributes' => attributes.except('id', 'type', 'created_at', 'updated_at', 'relationships') }
      h['data']['id'] = id if id.present?
      h
    end

    def self.find(*arguments)
      scope = arguments.slice!(0)
      options = (arguments.slice!(0) || {}).with_indifferent_access
      arrange_options(options)
      super(scope, options).tap do |object|
        make_pageable object, options
      end
    end

    def self.filters(params)
      h = {}.tap do |filters|
        params.each do |attr, value|
          unless PREDICATES.include?(attr.split('_').last)
            attr = if value.is_a? Enumerable
               "#{attr}_in"
            else
               "#{attr}_eq"
            end
          end
          filters[attr] = value
        end
      end
      { filter: h }
    end

    def self.make_pageable(object, options)
      return object unless object.is_a? ActiveResource::PaginatedCollection
      # Need to set from so paginated collection can use it for page calls.
      object.tap do |collection|
        collection.from = options['from']
        collection.original_params = options['params']
      end
    end

    def self.arrange_options(options)
      if options[:params].present?
        page = options[:params][:page] ? { page: options[:params].delete(:page) } : {}
        options[:params].merge!(options[:params].delete(:filter)) if options[:params][:filter]
        options[:params] = filters(options[:params]).merge!(page)
      end
      if options[:include].present?
        options[:params] ||= {}
        options[:params].merge!(options.extract!(:include))
      end
    end
  end
end
