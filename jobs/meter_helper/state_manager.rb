require 'json'

# Persists consumption period baselines to disk so they survive process restarts.
# All values are in kWh, matching the contract of GridMeasurements.
#
# Usage:
#   state = StateManager.load   # => Hash or nil on error/missing file
#   StateManager.save(day: {...}, month: {...}, year: {...})
class StateManager
  def self.state_file
    ENV.fetch('STATE_FILE', '/data/state.json')
  end

  def self.load
    data = JSON.parse(File.read(state_file))
    return nil unless data.key?('day') && data.key?('month') && data.key?('year')
    data
  rescue Errno::ENOENT
    puts "[StateManager] State file not found at #{state_file} — starting fresh"
    nil
  rescue JSON::ParserError => e
    puts "[StateManager] Corrupted state file: #{e.message} — starting fresh"
    nil
  rescue => e
    puts "[StateManager] Unexpected error loading state: #{e.message} — starting fresh"
    nil
  end

  # Atomic write: .tmp + rename ensures the file is never half-written
  def self.save(day:, month:, year:)
    tmp_path = state_file + '.tmp'
    payload = {
      'saved_at' => Time.now.iso8601,
      'day'      => day,
      'month'    => month,
      'year'     => year
    }
    File.write(tmp_path, JSON.pretty_generate(payload))
    File.rename(tmp_path, state_file)
    puts "[StateManager] State saved to #{state_file}"
  rescue => e
    puts "[StateManager] Failed to save state: #{e.message}"
  end
end
