require_relative 'test_helper'
require_relative '../jobs/grid_watts'

class GridWattsTest < Minitest::Test
  # Vorzeichen-Konvention (PowerwallClient): positiv = Laden, negativ = Entladen
  # Gesamtlast = Solar + Netzbezug - Einspeisung + Batterie-Entladung
  # Batterie-Laden ist im Zähler bereits sichtbar (keine Extra-Korrektur nötig).
  # Batterie-Entladen ist für den Zähler unsichtbar → muss addiert werden.

  def test_current_consumption_without_battery
    # Solar: 3000W, Bezug: 500W, keine Einspeisung, keine Batterie
    assert_equal(3500, current_consumption(3000, 500, 0, 0))
  end

  def test_current_consumption_with_feed_no_battery
    # Solar: 3000W, kein Bezug, 500W Einspeisung, keine Batterie
    assert_equal(2500, current_consumption(3000, 0, 500, 0))
  end

  def test_current_consumption_battery_discharging
    # Batterie entlädt 2000W → battery_power = -2000, battery_discharge = 2000
    # Gesamtlast = 1000 + 500 - 0 + 2000 = 3500
    assert_equal(3500, current_consumption(1000, 500, 0, -2000))
  end

  def test_current_consumption_battery_charging
    # Batterie lädt 2000W → battery_power = +2000, battery_discharge = 0
    # Laden bereits im Zähler sichtbar → keine Korrektur
    # Gesamtlast = 5000 + 0 - 1000 + 0 = 4000 (Haus 2000W + Batterieladen 2000W)
    assert_equal(4000, current_consumption(5000, 0, 1000, 2000))
  end

  def test_current_consumption_defaults_battery_to_zero
    # Rückwärtskompatibilität: 3-Argument-Aufruf muss weiterhin funktionieren
    assert_equal(2500, current_consumption(3000, 0, 500))
  end
end
