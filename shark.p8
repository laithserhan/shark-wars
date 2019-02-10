pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--shark
--by a2

function _init()
  add_mode("intro",intro_init,intro_update,intro_draw)
  add_mode("game",game_init,game_update,game_draw)
  set_mode("intro")
end

function _update()
  mode:update()
end

function _draw()
  mode:draw()
end

--valid layer indices (update here to allow new z-values)
game_layers={-1,0,1}
-->8
--modes
function add_mode(name,init,update,draw,skip_default)
  function wrap(default,custom)
    return function(mode)
      if (not skip_default) default(mode)
      custom(mode)
    end
  end

  local new_mode={
    name=name,
    init=wrap(default_init,init),
    update=wrap(default_update,update),
    draw=wrap(default_draw,draw)
  }

  if (all_modes==nil) all_modes={}
  all_modes[name]=new_mode
  return new_mode
end

function set_mode(name)
  mode=all_modes[name]
  assert(mode!=nil,"undefined mode "..name)
  mode:init()
end

function default_init(mode)
  --game objects
  local layer
  mode.game_objects={}
  for layer in all(game_layers) do
    mode.game_objects[layer]={}
  end
end

function default_update(mode)
  --update all game objects
  foreach_game_object(function(obj,layer)
    obj:update()
  end)

  --filter out "dead" objects
  filter_out_finished()
end

function default_draw(mode)
  cls(0)--clear the screen

  --draw visible game objects
  foreach_game_object(function(obj)
    if (obj.visible) obj:draw()
  end)
end
-->8
--intro loop
function cprint(clr,text)
  color(clr)
  print(text)
end

function intro_init(mode)
  mode.message=1
  mode.messages={
    function(h,d)
      cprint(h,"[nasa says]")
      cprint(d,"we have received a message\nfrom the aliens on enceladus,\nthe moon of saturn.")
      cprint(h,"\n⬆️⬇️ navigate - ❎ skip intro\n")
    end,
    function(h,d)
      cprint(h,"[the message reads]")
      cprint(d,"there is a threat!\nit comes from a faraway galaxy!\nplease save us!!\n")
    end,
    function(h,d)
      cprint(h,"[meanwhile]")
      cprint(d,"to protect the solar system\nand earth, nasa decides to help\nthe aliens fight by sending\nvery advanced weapons.\n")
    end,
    function(h,d)
      cprint(d,"but alas, nasa accidentally sent\ntheir top-secret experiment:\nshark x... duh duh duhhhh\n")
    end,
    function(h,d)
      cprint(h,"[nasa says]")
      cprint(d,"oh no! shark x should never have")
      cprint(d,"left the laboratory.\n")
    end,
    function(h,d)
      cprint(d,"no one knows how it will perform")
      cprint(d,"but it is too late to abort")
      cprint(d,"the mission.\n")
    end,
    function(h,d)
      cprint(d,"the threat is already at")
      cprint(d,"our gates!\n")
    end,
    function(h,d)
      cprint(d,"your mission, should you choose")
      cprint(d,"to accept it:\n")
    end,
    function(h,d)
      cprint(d,"remote control the shark and")
      cprint(d,"make sure the threat does not")
      cprint(d,"get past saturn.\n")
    end,
    function(h,d)
      cprint(d,"the future of humanity,")
      cprint(d,"and all alien-kind,")
      cprint(d,"rests between your fins.\n")
    end,
    function(h,d)
      cprint(d,"good luck, shark x.\n")
    end,
    function(h,d)
      cprint(h,"press 🅾️ to start")
    end
  }
end

function intro_update(mode)
  if btnp(4) and mode.message==#mode.messages then
    set_mode("game")
  elseif btnp(5) then
    mode.message=#mode.messages
  elseif btnp(2) and mode.message>1 then
    mode.message-=1
  elseif btnp(3) and mode.message<#mode.messages then
    mode.message+=1
  end
end

function intro_draw(mode)
  local h=5--header
  local d=5--dialog

  local m
  for m=max(1,mode.message-2),mode.message do
    if m>=mode.message then
      h=10
      d=7
    end
    mode.messages[m](h,d)
  end
end
-->8
--game loop
function game_init(mode)
  --gameplay view constraints
  mode.min_y=9
  mode.max_y=128

  --start score counter at zero
  mode.score=0

  --create initial objects
  make_starfield_generator(5,0.05)--1/20, dk gray
  make_starfield_generator(6,0.25)--1/4, lt gray
  make_starfield_generator(7,0.5)--1/2, white
  make_shark(8,60)
end

function game_update(mode)
end

function game_draw(mode)
  rectfill(0,0,128,6,5)
  print("score:"..mode.score,1,1,7)
  --print("fps:"..stat(7),104,1,7)
end
-->8
--makers
function noop()
end

function make_game_object(name,x,y,z,props)
  local obj={
    name=name,
    x=x,
    y=y,
    visible=true,
    update=noop,
    draw=noop,
    draw_bounding_box=function(self,color)
      rect(self.x,self.y,self.x+self.width,self.y+self.height,color)
    end,
    center=function(self)
      return self.x+self.width/2,self.y+self.height/2
    end,
    overlaps=function(self,other)
      return bounding_boxes_overlapping(self,other)
    end
  }
  --add additional properties
  local key,value
  for key,value in pairs(props) do
    obj[key]=value
  end
  --add it to layer `z` in game objects
  assert(mode.game_objects[z]!=nil,"update game_layers to use z="..z)
  add(mode.game_objects[z],obj)
  --return the game object
  return obj
end

function make_shark(x,y)
  return make_game_object("shark",x,y,0,{
    width=8,
    height=8,
    charge=50,
    charge_max=50,
    update=function(self)
      --shoot on 🅾️
      if btn(4) then
        if self.charge>0 then
          self.charge-=1
          sfx(1)
          if self.last_laser then
            self.last_laser.x-=1
            self.last_laser.width+=1
          else
            self.last_laser=make_laser(self.x+6,self.y)
          end
        end
      else
        self.charge=min(self.charge_max,self.charge+0.25)
        --shark only moves when not shooting lasers
        if (btn(2) and self.y>mode.min_y) self.y-=1
        if (btn(3) and self.y+self.height<mode.max_y) self.y+=1
        self.last_laser=nil
      end
    end,
    charge_bar_color=function(self)
      local percent=self.charge/self.charge_max
      if percent>0.75 then
        return 11
      elseif percent>0.5 then
        return 10
      elseif percent>0.25 then
        return 9
      else
        return 8
      end
    end,
    draw=function(self)
      palt(0,false)
      palt(1,true)
      spr(0,self.x,self.y)
      palt()

      local percent=self.charge/self.charge_max
      line(-1,7,flr(percent*129)-1,7,self:charge_bar_color())
    end,
  })
end

function make_laser(x,y)
  return make_game_object("laser",x,y,1,{
    width=1,
    height=1,
    update=function(self)
      self.x+=1
      if (self.x>128) self.finished=true
    end,
    draw=function(self)
      line(self.x,self.y,self.x+self.width-1,self.y+self.height-1,8)
    end
  })
end

function _initial_stars(count)
  local i
  local stars={}
  for i=1,count do
    add(stars,{x=rndb(0,127),y=rndb(0,127)})
  end
  return stars
end

function _make_starfield(x,color,speed)
  return make_game_object("starfield",x,0,-1,{
    width=128,
    height=128,
    stars=_initial_stars(10),
    update=function(self)
      self.x-=speed
    end,
    draw=function(self)
      local star
      for star in all(self.stars) do
        pset(self.x+star.x,self.y+star.y,color)
      end
    end
  })
end

function make_starfield_generator(color,speed)
  return make_game_object("starfield_generator",0,0,-1,{
    max=128,
    starfields={_make_starfield(0,color,speed)},
    visible=false,
    update=function(self)
      local field
      local max=0
      for field in all(self.starfields) do
        if field.x+field.width<0 then
          field.finished=true
        elseif field.x+field.width>max then
          max=field.x+field.width
        end
      end

      if max<128 then
        add(self.starfields,_make_starfield(max,color,speed))
        max+=128
      end

      self.max=max
    end
  })
end
-->8
--helpers
--hit detection helper functions
function rects_overlapping(left1,top1,right1,bottom1,left2,top2,right2,bottom2)
  return right1>left2 and right2>left1 and bottom1>top2 and bottom2>top1
end

function bounding_boxes_overlapping(obj1,obj2)
  return rects_overlapping(obj1.x,obj1.y,obj1.x+obj1.width,obj1.y+obj1.height,obj2.x,obj2.y,obj2.x+obj2.width,obj2.y+obj2.height)
end

function foreach_game_object(callback)
  local layer,obj
  for layer in all(game_layers) do
    local list=mode.game_objects[layer]
    for obj in all(list) do
      callback(obj,layer,list)
    end
  end
end

function foreach_game_object_named(name,callback)
  foreach_game_object(function(obj,layer,list)
    if (obj.name==name) callback(obj,layer,list)
  end)
end

function rndb(low,high)
  return flr(rnd(high-low+1)+low)
end

function ternary(condition,if_true,if_false)
  return condition and if_true or if_false
end

--increment a counter, wrapping to 20000 if it risks overflowing
function increment_counter(n)
  return n+ternary(n>32000,-12000,1)
end

--decrement a counter but not below 0
function decrement_counter(n)
  return max(0,n-1)
end

function filter_out_finished()
  foreach_game_object(function(obj,layer,list)
    if (obj.finished) del(list,obj)
  end)
end
__gfx__
111155e1000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11156111005555590000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
61166611055e55a80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6666666665ee55500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666066055e55a80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
61766771005555590000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11161111000005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111611111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111661155110000000005500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111155555c11000000005550055a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
61111166666611110000055555555589000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
61116666666666110005555555555589000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6616666666666661055555ee5555555a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666006665555eeee55555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666006665555eeee55555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6666666666666666055555ee5555555a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
661776666666fff10005555555555589000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
61117766667777110000055555555589000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6111176661111111000000005550055a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111166111111110000000005500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010200000c6100c6100c6100c6100c6100c6100c6100c6100d6000d6000d6000d6000d60016600026000160016600166001660005600076000860008600086000860000600006000060000600006000060000600
010100002b020240202b00019000120000b0000800005000040000300002000020000100005000040000300002000010000100010000070001000010000110001300014000100000000000000000000000000000
