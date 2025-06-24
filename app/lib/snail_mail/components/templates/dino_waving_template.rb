# frozen_string_literal: true

module SnailMail
  module Components
    module Templates
      class DinoWavingTemplate < TemplateBase
        def self.template_name
          "Dino Waving"
        end

        def self.show_on_single?
          true
        end

        def view_template
          image(
            image_path("dino-waving.png"),
            at: [333, 163],
            width: 87,
          )

          # Render return address
          render_return_address(10, 278, 260, 70, size: 10)

          # Render destination address in speech bubble
          render_destination_address(
            88,
            166,
            236,
            71,
            size: 16, valign: :bottom, align: :left
          )

          # Render IMb barcode
          render_imb(240, 24, 183)
          render_qr_code(5, 65, 60)
          render_letter_id(10, 19, 10)
          render_postage
        end
      end
    end
  end
end
