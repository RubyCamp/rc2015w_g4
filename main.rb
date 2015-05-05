require 'dxruby'
require_relative '../ruby-ev3/lib/ev3'
require 'date'

class Carrier
  CLAW_MOTOR = "A"
  RIGHT_MOTOR = "B"
  LEFT_MOTOR = "C"
  GYLO_SENSOR = "1"
  DISTANCE_SENSOR = "2"
  COLOR_SENSOR = "3"
  PORT = "COM3"
  WHEEL_SPEED = 50
  CLAW_POWER = 100
  DEGREES_CLAW = 5500

  attr_reader :distance
  attr_reader :distance01
  attr_reader :color
  attr_reader :color01
  attr_reader :pcolor
  attr_reader :timer
  attr_reader :keika
  attr_reader :rotation
  attr_reader :rotation01
  attr_reader :digree
  attr_reader :digree01
  attr_reader :targetdistance

  include Math

  def initialize
    @brick = EV3::Brick.new(EV3::Connections::Bluetooth.new(PORT))
    @brick.connect
    @busy = false
    @grabbing = false
    @timer = DateTime.now
    @brick.clear_all
    @pcolor = []
    @targetdistance = 0
    @digree01 = 0
  end

  # 前進する
  def run_forward(speed=WHEEL_SPEED)
    operate do
      @brick.reverse_polarity(*wheel_motors)
      @brick.start(speed, *wheel_motors)
      @digree01 += @digree
      @brick.clear_all
    end
  end

  # バックする
  def run_backward(speed=WHEEL_SPEED)
    operate do
      @brick.clear_all
      @brick.start(speed, *wheel_motors)
      @digree01 += @digree
      @brick.clear_all
    end
  end

  # 右に回る
  def turn_right(speed=WHEEL_SPEED)
    operate do
      @brick.clear_all
      @brick.reverse_polarity(RIGHT_MOTOR)
      @brick.start(speed, *wheel_motors)
      @digree01 += @digree
      @brick.clear_all
    end
  end

  # 左に回る
  def turn_left(speed=WHEEL_SPEED)
    operate do
      @brick.clear_all
      @brick.reverse_polarity(LEFT_MOTOR)
      @brick.start(speed, *wheel_motors)
      @digree01 += @digree
      @brick.clear_all
    end
  end

  # 動きを止める
  def stop
    @brick.stop(true, *all_motors)
    @brick.run_forward(*all_motors)
    @busy = false
    @brick.reset(RIGHT_MOTOR)
  end

  # ある動作中は別の動作を受け付けないようにする
  def operate
    unless @busy
      @busy = true
      yield(@brick)
    end
  end

  def update
    @color01 = @brick.get_sensor(COLOR_SENSOR, 2)
    @targetdistance = @brick.get_sensor(DISTANCE_SENSOR,0)
    @digree = @brick.get_sensor(GYLO_SENSOR, 0)
    case @color01
    when 0
      @color = "境界"
    when 1
      @color = "黒\n  そのまま"
    when 2
      @color = "青\n  荷物置き場"
    when 3
      @color = "緑\n  荷物"
    when 4
      @color = "黄\n  分岐"
    when 5
      @color = "赤\n  ポイント"
    when 6
      @color = "白\n  ダメダメ"
    when 7
      @color = "茶\n  危ない"
    else
      @color = ""
    end
  end

  def push_current_color(current_color)
    if @pcolor[-1] != current_color && current_color != 0 && current_color != 6 && current_color != 7
      if current_color != 2 || current_color == 2 && @pcolor[-1] == 1 && @pcolor[-2] == 4
        if current_color != 3 || current_color == 3 && @pcolor[-1] == 1 && @pcolor[-2] == 4
          if current_color != 4 || current_color == 4 && @pcolor[-2] != 2
            if current_color != 4 || current_color == 4 && @pcolor[-2] != 3
              @pcolor.push(current_color)
            end
          end
        end
      end
    end
  end

  # センサー情報の更新とキー操作受け付け
  def run
    update
    run_forward if Input.keyDown?(K_UP)
    run_backward if Input.keyDown?(K_DOWN)
    turn_left if Input.keyDown?(K_LEFT)
    turn_right if Input.keyDown?(K_RIGHT)
    grab if Input.keyDown?(K_P)
    release if Input.keyDown?(K_O)
    delete_color if Input.keyPush?(K_D)
    stop if [K_UP, K_DOWN, K_LEFT, K_RIGHT, K_P, K_O].all?{|key| !Input.keyDown?(key) }
  end

  # 終了処理
  def close
    stop
    @brick.clear_all
    @brick.disconnect
  end

  # "～_MOTOR" という名前の定数すべての値を要素とする配列を返す
  def all_motors
    @all_motors ||= self.class.constants.grep(/_MOTOR\z/).map{|c| self.class.const_get(c) }
  end

  def wheel_motors
    [LEFT_MOTOR, RIGHT_MOTOR]
  end

  #ものをつかむ
  def grab
    return if @grabbing
    operate do
      @brick.reverse_polarity(CLAW_MOTOR)
      @brick.step_velocity(CLAW_POWER,DEGREES_CLAW,0,CLAW_MOTOR)
      @brick.motor_ready(CLAW_MOTOR)
      @grabbing = true
    end
  end

  #ものを離す
  def release
    return unless @grabbing
    operate do
      @brick.step_velocity(CLAW_POWER,DEGREES_CLAW,0,CLAW_MOTOR)
      @brick.motor_ready(CLAW_MOTOR)
      @grabbing = false
    end
  end

  def delete_color
    @pcolor.pop
  end

  def timer
    startTime = @timer.strftime("%H時%M分%S秒")
  end

  def keika
    zikan = DateTime.now
    nowTime = zikan.min * 60 + zikan.sec
    startTime = @timer.min * 60 + @timer.sec
    sabun = nowTime - startTime
  end
end

begin
  puts "starting..."
  font = Font.new(32)
  Window.caption = "Ruビギナーズ"
  Window.width   = 800
  Window.height  = 600

  bg_img = Image.load("images/background.png")
  st_gl = Image.load("images/start.png")
  road = Image.load("images/road.png")
  blue = Image.load("images/blue.png")
  yellow = Image.load("images/yellow.png")
  green = Image.load("images/green.png")
  point = Image.load("images/point.png")
  carrier = Carrier.new
  puts "connected..."

  Window.loop do
  Window.draw(0, 0, bg_img)
  carrier.push_current_color(carrier.color01)
  carrier.pcolor.each_with_index { |item,id|
      case item
      when 1
        if carrier.pcolor[id-1] == 4 && id-1 != -1
          Window.draw(25*(id-1)+50, 50+25,road)
        else
          Window.draw(25*id+50, 50,road)
        end
      when 2
        if carrier.pcolor[id-2] == 4 && id-1 != -1
          Window.draw(25*(id-2)+50, 50+50,blue)
        else
          Window.draw(25*id+50, 50,blue)
        end
      when 3
        if carrier.pcolor[id-2] == 4 && id-1 != -1
          Window.draw(25*(id-2)+50, 50+50,green)
        else
          Window.draw(25*id+50, 50,green)
        end
      when 4
        Window.draw(25*id+50, 50,yellow)
      when 5
        Window.draw(25*id+50, 50,point)
      else
        Window.draw(25*id+50, 50, st_gl)
      end
  }

  break if Input.keyDown?(K_SPACE)
  carrier.run
  Window.draw_font(0, 450, "・カラー \n #{carrier.color}", font,:color=>[255,255,153])
  Window.draw_font(200, 450, "・障害物距離 \n #{carrier.targetdistance.to_i}cm", font,:color=>[255,153,255])
  Window.draw_font(450, 450, "・現在の角度 \n #{carrier.digree01}度",font,:color=>[153,204,255])
  Window.draw_font(650, 450, "・経過時間 \n #{carrier.keika}秒",font,:color=>[204,153,255])
end
rescue
  puts $!
  puts $!.backtrace
  p $!
  $!.backtrace.each{|trace| puts trace}

# 終了処理は必ず実行する
ensure
  puts "closing..."
  carrier.close if carrier
  puts "finished..."
end
