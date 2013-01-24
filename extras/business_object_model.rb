module BusinessObjectModel
  @business_object_models = nil

  def self.included(model)
    model.class_eval do
    end
    model.extend(ClassMethods)

    if model.ancestors.include?(ActiveRecord::Base)
      @business_object_models = [] if @business_object_models.nil?
      @business_object_models.push(model)
    end
  end

  def self.business_object_models
    @business_object_models
  end

  def systems
    Relationship.where(
      :source_type => self.class.name, :source_id => id,
      :destination_type => 'System',
      :relationship_type_id => "#{self.class.name.underscore}_has_process"
    ).includes(:destination).map(&:destination)
  end

  def dependent_self_objects
    Relationship.where(
      :source_type => self.class.name, :source_id => id,
      :destination_type => self.class.name,
      :relationship_type_id => "#{self.class.name.underscore}_relies_upon_#{self.class.name.underscore}"
    ).includes(:destination).map(&:destination)
  end

  def risky_attributes
    Relationship.where(
      :source_type => self.class.name,
      :source_id => id,
      :relationship_type_id => "#{self.class.name.underscore}_has_risky_attribute"
    ).includes(:destination).map(&:destination)
  end

  module ClassMethods
  end

end
