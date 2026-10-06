require File.expand_path('../../test_helper', __FILE__)

class InlineEditLocalesTest < ActiveSupport::TestCase
  LOCALES_DIR = File.expand_path('../../../config/locales', __FILE__)

  def plugin_locales
    Dir[File.join(LOCALES_DIR, '*.yml')].to_h do |file|
      lang = File.basename(file, '.yml')
      [lang, YAML.load_file(file).fetch(lang).keys.sort]
    end
  end

  def test_the_shipped_locales_should_have_the_same_keys
    locales = plugin_locales
    assert_include 'nl', locales.keys
    locales.each do |lang, keys|
      assert_equal locales['en'], keys, "config/locales/#{lang}.yml"
    end
  end

  def test_every_key_should_be_used_by_the_plugin
    sources = Dir[File.expand_path('../../../{app,lib}/**/*.{rb,erb}', __FILE__)].map { |f| File.read(f) }.join("\n") +
              File.read(File.expand_path('../../../init.rb', __FILE__))
    plugin_locales['en'].each do |key|
      # permission labels are looked up by Redmine as permission_<name>
      used = key.start_with?('permission_') ? sources.include?(":#{key.delete_prefix('permission_')}") : sources.include?(key)
      assert used, "#{key} is not used"
    end
  end

  def test_dutch_labels
    assert_equal 'Inline bewerken', ::I18n.t(:button_inline_edit, :locale => :nl)
    assert_equal 'Issues inline bewerken', ::I18n.t(:permission_issues_inline_edit, :locale => :nl)
  end
end
