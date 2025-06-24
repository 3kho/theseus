module SnailMail
  module Components
    class BaseComponent < Phlex::PDF
      include SnailMail::Helpers

      # Template sizes in points [width, height]
      SIZES = {
        standard: [6 * 72, 4 * 72], # 4x6 inches (432 x 288 points)
        envelope: [9.5 * 72, 4.125 * 72], # #10 envelope (684 x 297 points)
        half_letter: [8 * 72, 5 * 72], # half-letter (576 x 360 points)
      }.freeze

      # Template configuration methods - can be overridden in subclasses
      def self.template_name
        name.demodulize.underscore.sub(/_component$/, "")
      end

      def self.template_size
        :standard # default to 4x6 standard
      end

      def self.show_on_single?
        false
      end

      def self.template_description
        "A label template"
      end

      attr_reader :letter, :options

      def initialize(letter:, **options)
        @letter = letter
        @options = options
        super()
      end

      # Size in points [width, height]
      def size
        SIZES[self.class.template_size] || SIZES[:standard]
      end

      # Override in subclasses to define the template
      def view_template
        raise NotImplementedError, "Subclasses must implement view_template"
      end

      protected

      # Helper methods to render components
      def render_return_address(x, y, width, height, **options)
        render ReturnAddressComponent.new(letter: letter, x: x, y: y, width: width, height: height, **options)
      end

      def render_destination_address(x, y, width, height, **options)
        render DestinationAddressComponent.new(letter: letter, x: x, y: y, width: width, height: height, **options)
      end

      def render_imb(x, y, width, **options)
        render IMbComponent.new(letter: letter, x: x, y: y, width: width, **options)
      end

      def render_qr_code(x, y, size = 70)
        render QRCodeComponent.new(letter: letter, x: x, y: y, size: size, **options)
      end

      def render_letter_id(x, y, size, **opts)
        render LetterIdComponent.new(letter: letter, x: x, y: y, size: size, **opts.merge(options))
      end

      def render_postage(x = nil)
        render PostageComponent.new(letter: letter, x: x, **options)
      end

      def render_speech_bubble(**opts)
        render SpeechBubbleComponent.new(letter: letter, **opts.merge(options))
      end
    end
  end
end
