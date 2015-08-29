require 'readline'

class SWindow
  attr_reader :prompt
  @@id = 0
  @@active = nil

  def SWindow._catch_suspend()
    # Trap ctrl-z, just like Metasploit
    orig_suspend = Signal.trap("TSTP") do
      if(@@active)
        @@active.deactivate()
      end
    end

    proc.call()

    Signal.trap("TSTP", orig_suspend)
  end

  @@input_thread = Thread.new() do
    begin
      _catch_suspend() do
        loop do
          begin
            while @@active.nil? do
            end

            str = Readline::readline(@@active.prompt, true)

            if(str.nil?)
              break
            end
            if(@@active.nil?)
              $stderr.puts("WARNING: there is no active session! Input's going nowhere")
              next
            end

            @@active._incoming(str)
          end
        end
      end

      $stderr.puts("Input thread is over")
    rescue Exception => e
      $stderr.puts(e)
      $stderr.puts(e.backtrace.join("\n"))
    end
  end

  @@id = 0

  def initialize(name = nil, prompt = nil, parent = nil, activate = false)
    @id = (@@id += 1)
    @name = name || "unnamed"
    @prompt = prompt || "%s %d>" % [@name, @id]
    @parent = parent
    @children = []
    @callback = nil
    @history = [""] * 100
    @typed_history = []

    if(@parent)
      @parent._add_child(self)
    end

    puts("New session created: #{@name}")
    if(@@active.nil? || activate)
      self.activate(false)
    end
  end

  def on_input()
    @callback = proc
  end

  def spawn(name = nil, prompt = nil)
    return SWindow.new(name, prompt, self, &proc)
  end

  def puts(str)
    if(@@active == self)
      $stdout.puts(str)
    end
    @history << str
  end

  def _add_child(child)
    @children << child
  end

  def puts_ex(str, to_parent = false, to_grandparents = false, to_children = false, to_grandchildren = false)
    puts(str)

    if(to_grandparents)
      @parent.puts_ex(str, false, true, false, false) if(@parent)
    elsif(to_parent)
      @parent.puts_ex(str, false, false, false, false) if(@parent)
    end

    if(to_grandchildren)
      @children.each do |child|
        child.puts_ex(str, false, false, false, true)
      end
    elsif(to_children)
      @children.each do |child|
        child.puts_ex(str, false, false, false, false)
      end
    end
  end

  def redraw()
    $stdout.puts("Hi?")
    $stdout.puts(@history.join("\n"))
    $stdout.puts(@prompt)
  end

  def activate(redraw = true)
    @@active = self
    if(redraw)
      self.redraw()
    end

    Readline::HISTORY.clear()
    @typed_history.each do |i|
      Readline::HISTORY << i
    end
  end

  def deactivate()
    if(@parent)
      @parent.activate()
    else
      $stdout.puts("No parent to activate")
    end
  end

  def _incoming(str)
    @history << str
    @typed_history << str

    if(@callback.nil?)
      puts("Input received, but nothing has registered to receive it")
      puts("Please wait and try again in a bit!")
      return
    end
    @callback.call(str)
  end

  def SWindow.wait()
    @@input_thread.join()
  end
end