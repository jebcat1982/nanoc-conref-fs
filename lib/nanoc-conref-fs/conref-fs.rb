require_relative 'conrefifier'

# Unsure why attr_accessor does not work here
module VariableMixin
  def self.variables
    @variables
  end

  def self.variables=(variables)
    @variables = variables
  end

  def self.fetch_data_file(association)
    reference = association.split('.')
    data = VariableMixin.variables['site']['data']
    while key = reference.shift
      data = data[key]
    end
    data
  end
end

class ConrefFS < Nanoc::DataSource
  include Nanoc::DataSources::Filesystem
  include VariableMixin
  include NanocConrefFS::Ancestry

  identifier :'conref-fs'

  # Before iterating over the file objects, this method loads the data folder
  # and applies it to an ivar for later usage.
  def load_objects(dir_name, kind, klass)
    load_data_folder if klass == Nanoc::Int::Item && @variables.nil?
    super
  end

  def load_data_folder
    data = Datafiles.process(@site_config)
    config = @site_config.to_h
    @variables = { 'site' => { 'config' => config, 'data' => data } }
    VariableMixin.variables = @variables
  end

  # This function calls the parent super, then adds additional metadata to the item.
  def parse(content_filename, meta_filename, _kind)
    meta, content = super
    page_vars = Conrefifier.file_variables(@site_config[:page_variables], content_filename)

    unless page_vars[:data_association].nil?
      association = page_vars[:data_association]
      toc = VariableMixin.fetch_data_file(association)
      meta[:parents] = create_parents(toc, meta)
      meta[:children] = create_children(toc, meta)
    end

    page_vars.each_pair do |name, value|
      meta[name.to_s] = value
    end
  end

  # This file reads each piece of content as it comes in. It also applies the conref variables
  # (demarcated by Liquid's {{ }} tags) using both the data/ folder and any variables defined
  # within the nanoc.yaml config file
  def read(filename)
    content = super
    return content unless filename.start_with?('content', 'layouts')
    @unparsed_content = content
    Conrefifier.liquify(filename, content, @site_config)
  end

  # This method is extracted from the Nanoc default FS
  def filename_for(base_filename, ext)
    if ext.nil?
      nil
    elsif ext.empty?
      base_filename
    else
      base_filename + '.' + ext
    end
  end

  # This method is extracted from the Nanoc default FS
  def identifier_for_filename(filename)
    if config[:identifier_type] == 'full'
      return Nanoc::Identifier.new(filename)
    end

    if filename =~ /(^|\/)index(\.[^\/]+)?$/
      regex = @config && @config[:allow_periods_in_identifiers] ? /\/?(index)?(\.[^\/\.]+)?$/ : /\/?index(\.[^\/]+)?$/
    else
      regex = @config && @config[:allow_periods_in_identifiers] ? /\.[^\/\.]+$/ : /\.[^\/]+$/
    end
    Nanoc::Identifier.new(filename.sub(regex, ''), type: :legacy)
  end
end
