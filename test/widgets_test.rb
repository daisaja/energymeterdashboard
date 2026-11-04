require_relative 'test_helper'

class WidgetsTest < Minitest::Test
  WIDGET_DIR = File.expand_path('../widgets', __dir__)

  # Smashing bindet die Widgets per `require_tree` alphabetisch ein. Erbt ein Widget
  # von einem anderen Widget (z.B. Nullnumber < Number), kann die Basisklasse beim
  # Laden noch undefiniert sein – der JS-Fehler bricht dann application.js ab und
  # zerstört alle Dashboards. Daher: jedes Widget erbt direkt von Dashing.Widget.
  def test_all_widgets_extend_dashing_widget_directly
    Dir.glob(File.join(WIDGET_DIR, '*', '*.coffee')).each do |file|
      File.read(file).scan(/^class\s+(\S+)\s+extends\s+(\S+)/).each do |klass, parent|
        assert_equal 'Dashing.Widget', parent,
                     "#{File.basename(file)}: #{klass} erbt von #{parent} – Ladereihenfolge nicht garantiert"
      end
    end
  end
end
