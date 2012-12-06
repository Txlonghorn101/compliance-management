module ImportHelper
  def trim_array(a)
    while !a.empty? && a.last.blank?
      a.pop
    end
    a
  end

  def validate_import_slug(object, object_name, expected_slug)
    raise ImportException.new("#{object_name} Code column does not exist") unless object["slug"]
    raise ImportException.new("#{object_name} Code does not match current program") unless object["slug"] == expected_slug
  end

  def validate_import_type(object, expected_type)
    type = object.delete("type")
    raise ImportException.new("First column must be Type") unless type
    raise ImportException.new("Type must be #{expected_type}") unless type == expected_type
  end

  def read_import_headers(import, import_map, object_name, rows)
    trim_array(rows.shift).map do |heading|
      if heading == "Type"
        key = 'type'
      else
        key = import_map[heading]
        import[:messages] << "Invalid #{object_name} heading #{heading}" unless key
      end
      key
    end
  end

  def read_import(import, import_map, object_name, rows)
    headers = read_import_headers(import, import_map, object_name, rows)

    import[object_name.pluralize.to_sym] = rows.map do |values|
      row = {}
      headers.zip(values).each do |k, v|
        if row.has_key?(k)
          row[k] = "#{row[k]},#{v}"
        else
          row[k] = v
        end
      end
      row
    end
  end

  def render_import_error(message=nil)
    render '/error/import_error', :layout => false, :locals => { :message => message }
  end

  def handle_import_person(attrs, key, warning)
    if attrs[key].present?
      if attrs[key].include?('@')
        attrs[key] = Person.find_or_create_by_email!({:email => attrs[key]})
      else
        warning[key.to_sym] << "invalid email"
      end
    end
  end

  # NOTE: This depends on person having been looked up and the person object put in attrs[key]
  def handle_import_object_person(object, attrs, key, role)
    person = attrs.delete(key)
    existing = object.object_people.detect {|x| x.role == role}

    if existing && existing.person != person
      existing.destroy
    end

    if person
      object.object_people.new({:role => role, :person => person}, :without_protection => true)
    end
  end

  def handle_import_category(object, attrs, key, category_scope_id)
    category = attrs.delete(key)

    if category.present?
      categories = category.split(',').map {|category| Category.find_or_create_by_name({:name => category, :scope_id => category_scope_id})}
      object.categories = categories
    end
  end

  def handle_import_systems(object, attrs, key)
    systems_string = attrs.delete(key)

    unless systems_string.nil?
      systems = systems_string.split(',').map do |slug|
        system = System.find_or_create_by_slug({:slug => slug, :title => slug, :infrastructure => false})
        system
      end
      object.systems = systems
    end
  end

  def handle_import_sub_systems(object, attrs, key)
    systems_string = attrs.delete(key)

    unless systems_string.nil?
      systems = systems_string.split(',').map do |slug|
        system = System.find_or_create_by_slug({:slug => slug, :title => slug, :infrastructure => false})
        system
      end
      object.sub_systems = systems
    end
  end

  def handle_import_relationships(object, related_string, related_class, relationship_type)
    if related_string.present?
      relateds = related_string.split(',').each do |slug|
        related = related_class.find_or_create_by_slug({:slug => slug, :title => slug})
        attrs = {:source_id => object.id, :source_type => object.class.name, :destination_id => related.id, :destination_type => related_class.name, :relationship_type_id => relationship_type}
        unless Relationship.exists?(attrs)
          Relationship.create!(attrs)
        end
      end
    end
  end

  def handle_import_documents(object, attrs, key)
    documents_string = attrs.delete(key)

    if documents_string.present?
      documents = parse_document_reference(documents_string).map do |attrs|
        doc = Document.find_or_create_by_link(attrs)
        doc
      end
      object.documents = documents
    end
  end

  def parse_document_reference(ref_string)
    ref_string.split("\n").map do |ref|
      ref =~ /(.*)\[(\S+)(:?.*)\](.*)/
      link = $2.nil? ? '' : $2
      if link.start_with?('//')
        link = "file:" + link
      end
      { :description => ($1.nil? ? '' : $1) + ($4.nil? ? '' : $4),
        :link => link, :title => ($3.present? ? $3 : link).strip }
    end
  end

  def handle_import_document_reference(object, attrs, key, warnings)
    ref_string = attrs.delete(key)
    if ref_string.present?
      documents = parse_document_reference(ref_string).map do |ref|
        begin
          Document.find_or_create_by_link!(ref)
        rescue
          warnings[key.to_sym] ||= []
          warnings[key.to_sym] << "invalid reference URL"
          nil
        end
      end.compact
      object.documents = documents
    end
  end
end
