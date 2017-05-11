#
# This module wraps the API for Raphael
# as long as we need it to render harpnotes
#
# note that the class variable @r is used by
# `self.r` in the native javascript
# of the methods
#
module Raphael

  #
  # This represents a Raphael element
  #
  class Element
    attr_accessor :unhighlight_color, :r, :conf_key, :conf_value, :startpos
    #
    # Constructor
    #
    # @param r [] The Raphael element
    #
    # @return [type] [description]
    def initialize(r)
      @r                  = r
      @conf_key           = "conf unknown"
      @startpos           = [0, 0]
      self["stroke-width"]=0.5
    end


    #
    # get a Raphael attribute
    # @param name [String] The name of the attribute
    #
    # @return [String] The value of the attribute
    def [](name)
      `self.r.attr(name)`
    end


    #
    # set the a Raphael attribute
    # @param name [String] The name of the attribute
    # @param value [Object] The value of the attribute
    #
    # @return [type] [description]
    def []=(name, value)
      `self.r.attr(name, value)`
    end

    # adjust the line width of the current Raphael element
    # @param [Numerical] width with of the elment in mm
    def line_width=(width)
      self["stroke-width"]=width
    end

    #
    # Wrap translate
    # @param x [Numeric] horizontal distance
    # @param y [Numeric] vertical distance
    #
    # @return [type] [description]
    def translate(x, y)
      `self.r.translate(x, y)`
    end

    #
    # Wrap transform
    #
    # @param [Object] cmd - http://raphaeljs.com/reference.html#Element.transform
    def transform(cmd)
      `self.r.transform(cmd)`
    end


    #
    # the the size of an object
    # @return [Native Javascript object] see http://raphaeljs.com/reference.html#Element.getBBox
    #
    def get_bbox()
      Native(`self.r.getBBox()`)
    end


    #
    # Add an on_click handler
    # @param block [type] [description]
    #
    # @return [type] [description]
    def on_click(&block)
      %x{
        var wrapper = function(evt) {
          return block.apply(null, arguments);
        };
        self.r.click(wrapper);
      }
    end

  end


  #
  # Wraps Raphael drawing area
  #
  class Paper

    #
    # Construtctor
    # @param element [String] The indentifier of the canvas element
    # @param width [Numeric] Width of the canvas in pixels
    # @param height [Numeric] Height of the canvas in pixels
    #
    # @return [type] [description]
    def initialize(element, width, height)
      @on_drag_end                  = lambda { |dropinfo| $log.info(dropinfo) }
      @on_mouseover_handler         = lambda { |dropinfo| $log.info(Native(dropinfo).conf_key) }
      @on_mouseout_handler          = lambda { |dropinfo| $log.info(Native(dropinfo).conf_key) }
      @draggable_rightclick_handler = lambda { |dropinfo|}

      @canvas     = [width, height]
      @scale      = 1
      @svgbuffer  = []
      @r          = `Raphael(#{element}, #{width}, #{height})` # this creates the raphael paper
      @line_width = 0.2 # todo:clarify value

      @svgbuffer.push (%Q{<svg width="#{width}" height="#{height}" viewBox="0, 0, 440, 297" > })  ## todo improve handling of viewbox
    end

    # @return the native raphael object
    def raw
      @r
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
      `self.r.clear()`
    end

    def on_mouseover(&block)
      @on_mouseover_handler = block
    end

    def on_mouseout(&block)
      @on_mouseout_handler = block
    end

    def on_annotation_drag_end(&block)
      @on_drag_end = block
    end

    def on_draggable_rightclick(&block)
      @draggable_rightclick_handler = block
    end


    # this attaches the context menu only
    def set_conf_editable(element)
      conf_key = element.conf_key
      %x{
          var me = #{element.r};
          mouseoverFnc = function(){
            #{@on_mouseover_handler}({element: me, conf_key: #{conf_key}})
          }

          mouseoutFnc = function(){
            #{@on_mouseout_handler}({element: me, conf_key: #{conf_key}})
          }

          me.mouseover(mouseoverFnc);
          me.mouseout(mouseoutFnc);
          me.node.oncontextmenu = function(){return #{@draggable_rightclick_handler}({element: element.r, conf_key: #{conf_key}});};
      }
    end

    # this makes the element draggable
    # it also includes a context menu
    def set_draggable(element)
      #inspired by http://wesleytodd.com/2013/4/drag-n-drop-in-raphael-js.html
      %x{
      #{element.r}.node.className.baseVal +=" zn_draggable"
         var otransform = element.r.transform(); // save the orginal transformation
         var me = #{element.r},
          lx = 0,
          ly = 0,
          ox = 0,
          oy = 0,
          moveFnc = function(dx, dy) {

            scale = this.paper._viewBox[3] / this.paper.canvas.height.baseVal.value ;
            lx = Math.round(scale * dx) + ox;
            ly = Math.round(scale * dy) + oy;

              if (doDrag) this.transform('t' + lx + ',' + ly + otransform);
          },

          startFnc = function(dx, dy, event) { (event.button == 0) ? doDrag=true: doDrag=false;},

          endFnc = function() {
            if (doDrag){
              ox = lx;
              oy = ly;
              element.r.attr({fill: 'red'});
              #{@on_drag_end}({element: me, "conf_key": element.conf_key, "conf_value": element.conf_value, "origin": element.startpos, "delta":  [ox, oy]} );
            }
          };

          mouseoverFnc = function(){
            #{@on_mouseover_handler}({element: me, conf_key: #{element}.conf_key})
          }

          mouseoutFnc = function(){
            #{@on_mouseout_handler}({element: me, conf_key: #{element}.conf_key})
          }

      me.drag(moveFnc, startFnc, endFnc);$scope.get('Element').$find("#" + (self.container_id))<
      me.mouseover(mouseoverFnc);
      me.mouseout(mouseoutFnc);

      me.node.oncontextmenu = function(){return #{@draggable_rightclick_handler}({element: element.r, conf_key: element.conf_key});};

      }
    end


    # Draw an ellipse
    #
    # @param x [Numeric] x - horizontal coordinate of center
    # @param y [Numeric] y - vertical coordinate of center
    # @param rx [Numeric] rx - horizontal radius
    # @param ry [Numeric] ry - vertical radius
    #
    # @return [element] The generated Element
    def ellipse(x, y, rx, ry)
      result            = Raphael::Element.new(`self.r.ellipse(x, y, rx, ry)`)
      result.line_width = @line_width
      result
    end

    #
    # Draw a path
    #
    # @param spec [String] The path to be drawn
    # see http://raphaeljs.com/reference.html#Paper.path
    #
    #
    # @return [Element] The generated Element
    def path(spec)
      result            = Raphael::Element.new(`self.r.path(spec)`)
      result.line_width = @line_width
      result
    end

    # Draw an Rectangle
    #
    # @param x [Numeric] x - of center
    # @param y [Numeric] y - of center
    # @param rx [Numeric] rx - horizontal radius
    # @param ry [Numeric] ry - vertical radius
    # @param radius [Numeric] radius for rounded corners, default is 0
    #
    # @return [element] The generated Element
    def rect_like_ellipse(x, y, rx, ry, radius = 0)
      result            = Raphael::Element.new(`self.r.rect(#{x}-#{rx}, #{y}-#{ry}, 2*#{rx}, 2*#{ry}, #{radius})`)
      result.line_width = @line_width
      result
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
    def rect(x, y, rx, ry, radius = 0)
      @svgbuffer.push(%Q{<rect x="#{x}" y="#{y}" width="#{rx}" height="#{ry}" ry="#{radius}" ry="#{radius}" style="fill:none;stroke-width:#{@line_width};stroke:rgb(0,0,0)" />})
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
    def line(x1, y1, x2, y2)
      path("M#{x1},#{y1}L#{x2},#{y2}")
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

      attrs = attributes.map{|k,v| %Q{#{k}="#{v}"}}
      tspans = text.split("\n").map{|l| %Q{<tspan dy="1.2em" x="#{x}">#{l}</tspan>}}

      @svgbuffer.push %Q{<text x="#{x}" y="#{y}"  #{attrs.join(" ")}>#{tspans.join()}</text>}
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
