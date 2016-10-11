BoxRadius=6
player1 = 1
buttons = {["A"]=false,["B"]=false,["up"]=false,["down"]=false,["left"]=false,["right"]=false}

-- function set_buttons ()
--   if (emu.framecount() % 50 == 0) then
--     jumping = not jumping
--     -- gui.savescreenshot()
--   end;
--   buttons["A"] = jumping
--   joypad.set(player1, buttons)
-- end

function set_state ()
  level1_start = savestate.object(1)
  savestate.save(level1_start)

end

function init ()
  set_state()
  -- emu.speedmode("maximum")
end

function getPositions()
  marioX = memory.readbyte(0x6D) * 0x100 + memory.readbyte( 0x86 )
  marioY = memory.readbyte(0x03B8)+16
  screenX = memory.readbyte(0x03AD)
  screenY = memory.readbyte(0x03B8)
end

function getTile(dx, dy)
  local x = marioX + dx + 8
  local y = marioY + dy - 16
  local page = math.floor(x/256)%2

  local subx = math.floor((x%256)/16)
  local suby = math.floor((y - 32)/16)
  local addr = 0x500 + page*13*16+suby*16+subx
 
  if suby >= 13 or suby < 0 then
          return 0
  end
 
  if memory.readbyte(addr) ~= 0 then
          return 1
  else
          return 0
  end
end

function getSprites()
  local sprites = {}
  for slot = 0,4 do
    local enemy = memory.readbyte( 0xF+slot)
    if enemy ~= 0 then
      local ex = memory.readbyte( 0x6E + tonumber(slot))* 0x100 + memory.readbyte( 0x87 + tonumber(slot))
      local ey = memory.readbyte( 0xCF + slot) + 24
      sprites[#sprites+1] = {["x"]=ex,["y"]=ey}
    end
  end 
  return sprites
end

function getInputs()
  getPositions()
  sprites = getSprites()
  local inputs = {}
 
  for dy=-BoxRadius*16,BoxRadius*16,16 do
    for dx=-BoxRadius*16,BoxRadius*16,16 do
      inputs[#inputs+1] = 0
     
      tile = getTile(dx, dy)
      if tile == 1 and marioY+dy < 0x1B0 then
        inputs[#inputs] = 1
      end
     
      for i = 1,#sprites do
        distx = math.abs(sprites[i]["x"] - (marioX+dx))
        disty = math.abs(sprites[i]["y"] - (marioY+dy))
        if distx <= 8 and disty <= 8 then
          inputs[#inputs] = -1
        end
      end
    end
  end
  -- print(inputs)
  return inputs
end

function printInput()
  os.execute("clear")
  Input=getInputs()
  i=1
  box_print=""
  for dy=-BoxRadius*16,BoxRadius*16,16 do
    for dx=-BoxRadius*16,BoxRadius*16,16 do
      box_print=box_print.." "..Input[i]
      i=i+1
    end
    box_print=box_print.."\n"
  end
  print(box_print)
end



function dead ()
  if memory.readbyte(0x000E) == 0x0B or memory.readbyte(0x000E) == 0x06 then
    return true;
  else
    return false;
  end
end


init()
while true do
  printInput()
  emu.message("X = " .. marioX ..", Y = " .. marioY)
  if dead() then
    emu.message("Dead")
    savestate.load(level1_start)
  end
  emu.frameadvance()
end
