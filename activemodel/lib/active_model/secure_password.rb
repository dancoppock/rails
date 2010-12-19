require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/class/attribute'
require 'bcrypt'

module ActiveModel
  module SecurePassword
    extend ActiveSupport::Concern

    included do
      class_attribute :weak_passwords
      self.weak_passwords = %w( password qwerty 123456 )
    end

    module ClassMethods
      # Adds methods to set and authenticate against a BCrypt password.
      # This mechanism requires you to have a password_digest attribute.
      #
      # Validations for presence of password, confirmation of password (using a "password_confirmation" attribute),
      # and strength of password (at least 6 chars, not "password", etc) are automatically added.
      # You can add more validations by hand if need be.
      #
      # Example using Active Record (which automatically includes ActiveModel::SecurePassword):
      #
      #   # Schema: User(name:string, password_digest:string)
      #   class User < ActiveRecord::Base
      #     has_secure_password
      #   end
      #
      #   user = User.new(:name => "david", :password => "secret", :password_confirmation => "nomatch")
      #   user.save                                                      # => false, password not long enough
      #   user.password = "mUc3m00RsqyRe"
      #   user.save                                                      # => false, confirmation doesn't match
      #   user.password_confirmation = "mUc3m00RsqyRe"
      #   user.save                                                      # => true
      #   user.authenticate("notright")                                  # => false
      #   user.authenticate("mUc3m00RsqyRe")                             # => user
      #   User.find_by_name("david").try(:authenticate, "notright")      # => nil
      #   User.find_by_name("david").try(:authenticate, "mUc3m00RsqyRe") # => user
      def has_secure_password
        attr_reader   :password
        attr_accessor :password_confirmation

        attr_protected(:password_digest) if respond_to?(:attr_protected)

        validates_confirmation_of :password
        validates_presence_of     :password_digest
        validate                  :password_must_be_strong
      end

      # Specify the weak passwords to be used in the model:
      #
      #   class User
      #     set_weak_passwords %w( password qwerty 123456 mypass )
      #   end
      def set_weak_passwords(values)
        self.weak_passwords = values
      end
    end

    # Returns self if the password is correct, otherwise false.
    def authenticate(unencrypted_password)
      if BCrypt::Password.new(password_digest) == unencrypted_password
        self
      else
        false
      end
    end

    # Encrypts the password into the password_digest attribute.
    def password=(unencrypted_password)
      @password = unencrypted_password
      self.password_digest = BCrypt::Password.create(unencrypted_password)
    end

    private

    def password_must_be_strong
      if password.present?
        errors.add(:password, :too_short, :count => 7) unless password.size > 6
        errors.add(:password, :insecure) if self.class.weak_passwords.include?(password)
      end
    end
  end
end