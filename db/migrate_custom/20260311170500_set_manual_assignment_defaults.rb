class SetManualAssignmentDefaults < ActiveRecord::Migration[7.1]
  def up
    change_column_default :inboxes, :enable_auto_assignment, from: true, to: false
    change_column_default :teams, :allow_auto_assign, from: true, to: false
  end

  def down
    change_column_default :inboxes, :enable_auto_assignment, from: false, to: true
    change_column_default :teams, :allow_auto_assign, from: false, to: true
  end
end
