class ConversationPolicy < ApplicationPolicy
  def index?
    true
  end

  def destroy?
    @account_user&.administrator?
  end

  def toggle_ai?
    true
  end
end
