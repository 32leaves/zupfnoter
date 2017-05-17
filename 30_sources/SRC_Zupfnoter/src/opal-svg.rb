#
# This module wraps the API for Raphael
# as long as we need it to render harpnotes
#
# note that the class variable @r is used by
# `self.r` in the native javascript
# of the methods
#
module ZnSvg

  #
  # This represents a Raphael element
  #

  #
  # Wraps Raphael drawing area
  #
  class Paper

    #
    # Construtctor
    # @param element [String] The indentifier of the canvas element # not used
    # @param width [Numeric] Width of the canvas in pixels
    # @param height [Numeric] Height of the canvas in pixels
    #
    # dropinfo: a js-object: {element: {svg-node}, conf_key: {conf_key}, conf_value: {value for conf_key}}
    # @return [type] [description]
    def initialize(element, width, height)
      @draggable_dragend_handler    = lambda { |dropinfo| $log.info(dropinfo) }
      @on_mouseover_handler         = lambda { |dropinfo| $log.info(Native(dropinfo).conf_key) }
      @on_mouseout_handler          = lambda { |dropinfo| $log.info(Native(dropinfo).conf_key) }
      @draggable_rightclick_handler = lambda { |dropinfo|}

      @canvas     = [width, height]
      @scale      = 1
      @svgbuffer  = []
      @id = 0

      @line_width = 0.2 # todo:clarify value

      clear
    end

    def new_id!
      "ZN_#{@id+=1}"
    end

    # @return the resulting SVG

    def get_svg
      @svgbuffer.push(%Q{</svg>})
      @svgbuffer.join
    end

    # @param [Numerical] width of line from now on
    def line_width=(width)
      @line_width = width
    end

    #
    # Clear the area
    #
    # @return [type] [description]
    def clear
      @id = 0
      @svgbuffer = []
      @svgbuffer.push(%Q{<svg width="#{@canvas.first}" height="#{@canvas.last}" viewBox="0, 0, 440, 297" > }) ## todo improve handling of viewbox
    end

    def on_mouseover(&block)
      @on_mouseover_handler = block
    end

    def on_mouseout(&block)
      @on_mouseout_handler = block
    end

    def on_annotation_drag_end(&block)
      @draggable_dragend_handler = block
    end

    # @param block: {element: {},  detla: {}, conf_key: {}, conf_val {} }
    def on_draggable_rightclick(&block)
      @draggable_rightclick_handler = block
    end


    # this attaches the context menu only
    #

    def set_conf_editable(svg_element, conf_key)
      %x{
          var me = #{svg_element};
          mouseoverFnc = function(){
            #{@on_mouseover_handler}({element: me, conf_key: #{conf_key}})
          }

          mouseoutFnc = function(){
            #{@on_mouseout_handler}({element: me, conf_key: #{conf_key}})
          }
          me.mouseover(mouseoverFnc);
          me.mouseout(mouseoutFnc);

          me[0].oncontextmenu = function(){ return #{@draggable_rightclick_handler}({element: svg_element, conf_key: #{conf_key}});};
      }
    end

    def set_draggable(svg_element, conf_key, conf_value)
      %x{
                xx = SVG.get(#{svg_element}[0].id)
                xx.addClass("zn_draggable")

                xx.draggable(function(x,y){return {x: Math.round(x), y:Math.round(y)}});

                var sx=0, sy=0;
                xx.on('dragstart', function(e){
                   sx = e.detail.p.x;
                   sy = e.detail.p.y;
                   this.fill("red")
                } );

                // todo: don't know why 'this' is the only way to change the filling ...
                xx.on('dragend',function(e){
                  this.fill("green");
                  #{@draggable_dragend_handler}( { delta: [e.detail.p.x - sx, e.detail.p.y - sy], element: #{svg_element}[0], conf_key: #{conf_key}, conf_value: #{conf_value} } )
                  } )
              }

    end



    def add_abcref(x, y, rx, ry)
      id = new_id!
      svg =%Q{<rect class="abcref" id="#{id}" x="#{x - rx - 1.5}" y="#{y - ry - 1.5 }" width="#{2 * rx+3}" height="#{2 * ry + 3}"/>}
      @svgbuffer.push(svg)
      id
    end


    # Draw an ellipse
    #
    # @param x [Numeric] x - horizontal coordinate of center
    # @param y [Numeric] y - vertical coordinate of center
    # @param rx [Numeric] rx - horizontal radius
    # @param ry [Numeric] ry - vertical radius
    #
    # @return [element] The generated Element
    def ellipse(x, y, rx, ry, attributes = {})
      attr = _attr_to_xml(attributes)
      svg  = %Q{<ellipse  cx="#{x}" cy="#{y}" rx="#{rx}" ry="#{ry}" stroke-width="#{@line_width}" #{attr}/>}
      @svgbuffer.push(svg)
      nil
    end

    #
    # Draw a path
    #
    # @param spec [String] The path to be drawn
    # see http://raphaeljs.com/reference.html#Paper.path
    #
    #
    # @return [Element] The generated Element
    def path(spec, attributes={})
      attrs = _attr_to_xml(attributes)
      id = new_id!
      @svgbuffer.push %Q{<g id="#{id}"><path class="znunhighlight" stroke-width="#{@line_width}" d="#{spec}" #{attrs}/></g>}
      id
    end


    # Draw an Rectangle like an ellipse
    #
    # @param x [Numeric] x - of topleft corner
    # @param y [Numeric] y - of topleft corner
    # @param rx [Numeric] rx - width
    # @param ry [Numeric] ry - height
    # @param radius [Numeric] radius for rounded corners, default is 0
    #
    # @return [element] The generated Element
    def rect(x, y, rx, ry, radius = 0, attributes={fill: "none", stroke: "black", "stroke-width" => @line_width})
      id = new_id!
      attr = _attr_to_xml(attributes)
      #@svgbuffer.push(%Q{<rect x="#{x}" y="#{y}" width="#{rx}" height="#{ry}" rx="#{radius}" ry="#{radius}" style="fill:#{attr[:fill]};stroke-width:#{@line_width};stroke:#{attr[:stroke]}" />})
      @svgbuffer.push(%Q{<rect id="#{id}" x="#{x}" y="#{y}" width="#{rx}" height="#{ry}" rx="#{radius}" ry="#{radius}" #{attr} />})
      id
    end


    def set_view_box(x, y, width, height, fit)
      @scale = @canvas.last / height
      # todo change viewbox in @svgbugger if necessary
    end

    #
    # Draw a line
    #
    # @param x1 [Numeric] horiozontal startpoint coordinate
    # @param y1 [Numeric] vertical startpoint coordinate
    # @param x2 [Numeric] horiozontal endpoint coordinate
    # @param y2 [Numeric] vertical endpoint coordinate
    #
    # @return [Element] The generated Element
    def line(x1, y1, x2, y2, attributes = {})
      path("M#{x1},#{y1}L#{x2},#{y2}", attributes)
    end

    #
    # Draw a text
    #
    # @param x [Numeric] horiozontal startpoint coordinate
    # @param y [Numeric] horiozontal startpoint coordinate
    # @param text [String] The text to be rendered
    #
    # @return [Element] The generated Element
    def text(x, y, text, attributes={})
      id = new_id!
      attrs  = _attr_to_xml(attributes)
      tspans = text.split("\n").map { |l| %Q{<tspan dy="1.2em" x="#{x}">#{l}</tspan>} }.join()

      @svgbuffer.push %Q{<g id="#{id}" x="#{x}" y="#{y}"><text x="#{x}" y="#{y}" id="#{id}" #{attrs}>#{tspans}</text></g>}
     # $log.info %Q{<g id="#{id}"><text id="#{id}" x="#{x}" y="#{y}"  #{attrs}>#{tspans}</text></g>}
      id
    end

    def _attr_to_xml(attributes)
      attributes.map { |k, v| %Q{#{k}="#{v}"} }.join(" ")
    end

    #
    # Determine the size of the canvas
    #
    # @return [Array of Numeric] The horizontal, vertical dimensions
    # of the canvas
    def size
      [`self.r.canvas.offsetWidth`, `self.r.canvas.offsetHeight`]
    end

    def enable_pan_zoom
      `self.r.panzoom().enable()` if `self.r.panzoom != undefined`
    end

  end

end
