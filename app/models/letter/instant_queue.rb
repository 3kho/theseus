# == Schema Information
#
# Table name: letter_queues
#
#  id                         :bigint           not null, primary key
#  include_qr_code            :boolean          default(TRUE)
#  letter_height              :decimal(, )
#  letter_mailing_date        :date
#  letter_processing_category :integer
#  letter_return_address_name :string
#  letter_weight              :decimal(, )
#  letter_width               :decimal(, )
#  name                       :string
#  postage_type               :string
#  slug                       :string
#  tags                       :citext           default([]), is an Array
#  template                   :string
#  type                       :string
#  user_facing_title          :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  letter_mailer_id_id        :bigint
#  letter_return_address_id   :bigint
#  user_id                    :bigint           not null
#  usps_payment_account_id    :bigint
#
# Indexes
#
#  index_letter_queues_on_letter_mailer_id_id       (letter_mailer_id_id)
#  index_letter_queues_on_letter_return_address_id  (letter_return_address_id)
#  index_letter_queues_on_type                      (type)
#  index_letter_queues_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (letter_mailer_id_id => usps_mailer_ids.id)
#  fk_rails_...  (letter_return_address_id => return_addresses.id)
#  fk_rails_...  (user_id => users.id)
#  fk_rails_...  (usps_payment_account_id => usps_payment_accounts.id)
#
class Letter::InstantQueue < Letter::Queue
  # TODO: drop mailing date, wtf?

  # Validations
  validates :template, presence: true
  validates :postage_type, presence: true, inclusion: { in: %w[indicia stamps international_origin] }
  validates :usps_payment_account_id, presence: true, if: :indicia?
  validates :letter_mailing_date, presence: true, if: :indicia?

  # Associations
  belongs_to :usps_payment_account, class_name: "USPS::PaymentAccount", optional: true

  # Scopes
  default_scope { where(type: "Letter::InstantQueue") }

  # Methods
  def indicia?
    postage_type == "indicia"
  end

  def process_letter_instantly!(address, params = {})
    Rails.logger.info("Starting process_letter_instantly! with postage_type: #{postage_type}")

    letter = ActiveRecord::Base.transaction do
      # Create letter directly in pending state
      letter = letters.build(
        address: address,
        height: letter_height,
        width: letter_width,
        weight: letter_weight,
        return_address: letter_return_address,
        return_address_name: letter_return_address_name,
        usps_mailer_id: letter_mailer_id,
        processing_category: letter_processing_category,
        tags: tags,
        aasm_state: "pending",
        postage_type: postage_type,
        mailing_date: Date.current + 1.day,
        **params,
      )
      letter.save!
      Rails.logger.info("Created letter #{letter.id} with postage_type: #{letter.postage_type}")

      # Purchase indicia if needed
      if indicia?
        Rails.logger.info("Creating indicia for letter #{letter.id}")
        begin
          payment_account = USPS::PaymentAccount.find(usps_payment_account_id)
          Rails.logger.info("Found payment account #{payment_account.id}")

          # Create and save the indicium first
          indicium = USPS::Indicium.create!(
            letter: letter,
            payment_account: payment_account,
            mailing_date: letter.mailing_date,
          )
          Rails.logger.info("Created indicium #{indicium.id} for letter #{letter.id}")

          # Then buy the indicium
          indicium.buy!
          Rails.logger.info("Successfully bought indicium for letter #{letter.id}")

          # Reload the letter to ensure we have the latest indicium association
          letter.reload
          if letter.usps_indicium.present?
            Rails.logger.info("Verified indicium #{letter.usps_indicium.id} is associated with letter #{letter.id}")
          else
            Rails.logger.error("Indicium was not properly associated with letter #{letter.id} after creation")
            Rails.logger.error("Letter postage_type: #{letter.postage_type}")
            Rails.logger.error("Letter mailing_date: #{letter.mailing_date}")
            raise "Failed to associate indicium with letter"
          end
        rescue => e
          Rails.logger.error("Failed to create indicium for letter #{letter.id}: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          uuid = Honeybadger.notify(e)
          raise "Failed to create indicium (please report EID: #{uuid} immediately)"
        end
      end
      letter
    end

    # Verify indicium exists before generating label if using indicia
    letter.reload
    Rails.logger.info("Before generate_label - Letter #{letter.id} postage_type: #{letter.postage_type}")
    Rails.logger.info("Before generate_label - Letter #{letter.id} has indicium: #{letter.usps_indicium.present?}")

    if indicia? && !letter.usps_indicium.present?
      Rails.logger.error("No indicium found for letter #{letter.id} before generating label")
      Rails.logger.error("Letter postage_type: #{letter.postage_type}")
      Rails.logger.error("Letter mailing_date: #{letter.mailing_date}")
      raise "No indicium found for letter before generating label"
    end

    letter.generate_label(
      template: template,
      include_qr_code: include_qr_code,
    )
    letter
  end
end
