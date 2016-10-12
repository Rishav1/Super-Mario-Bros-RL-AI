BoxRadius=6
player1 = 1
TIMEOUT=10
-- function set_buttons ()
--   if (emu.framecount() % 50 == 0) then
--     jumping = not jumping
--     -- gui.savescreenshot()
--   end;
--   buttons["A"] = jumping
--   joypad.set(player1, buttons)
-- end

function set_imports()
  print(_VERSION)
  require("torch")
end

function set_state ()
  while(memory.readbyte(0x0772)~=0x03 or memory.readbyte(0x0770)~=0x01) do
    set_level(02,07)
    emu.frameadvance()
  end
  level_start = savestate.object(1)
  savestate.save(level_start)
end

function set_values()
  Returns={}
  Policy={}
end


function set_level(world,level)
  memory.writebyte(0x75F,world)
  memory.writebyte(0x75C,level)
  memory.writebyte(0x760,level)
end

function init ()
  set_imports()
  set_state()
  set_values()
  emu.speedmode("maximum")
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

function getHashReturns(Inputs, Action)
  local A_value=0
  for i=1,#Action do
    A_value=A_value*2
    if Action[i] then
      A_value=A_value+1
    end
  end
  local I_value=0
  for i=1,#Inputs do
    I_value=I_value*3
    if Inputs[i]==0 then
      I_value=I_value+0
    elseif Inputs[i]==1 then
      I_value=I_value+1
    else
      I_value=I_value+2
    end
  end
  return I_value*math.pow(2,#Action)+A_value
end

function getButtonsForAction(Action)
  local action_hash=Action
  local buttons = {["A"]=false,["B"]=false,["up"]=false,["down"]=false,["left"]=false,["right"]=false}
  if torch.all(torch.eq(action_hash%2,1)) then
    buttons["right"]=true
  else
    buttons["right"]=false
  end
  action_hash=action_hash/2
  if torch.all(torch.eq(action_hash%2,1)) then
    buttons["left"]=true
  else
    buttons["left"]=false
  end
  action_hash=action_hash/2
  if torch.all(torch.eq(action_hash%2,1)) then
    buttons["down"]=true
  else
    buttons["down"]=false
  end
  action_hash=action_hash/2
  if torch.all(torch.eq(action_hash%2,1)) then
    buttons["up"]=true
  else
    buttons["up"]=false
  end
  action_hash=action_hash/2
  if torch.all(torch.eq(action_hash%2,1)) then
    buttons["B"]=true
  else
    buttons["B"]=false
  end
  action_hash=action_hash/2
  if torch.all(torch.eq(action_hash%2,1)) then
    buttons["A"]=true
  else
    buttons["A"]=false
  end
  action_hash=action_hash/2
  if not torch.all(torch.eq(action_hash,0)) then
    eum.message("error, set button for hash didn't receive correct value\n")
  end
  return buttons
end

function getHashPolicy(Inputs)
  local I_value=0
  for i=1,#Inputs do
    I_value=I_value*3
    if Inputs[i]==0 then
      I_value=I_value+0
    elseif Inputs[i]==1 then
      I_value=I_value+1
    else
      I_value=I_value+2
    end
  end
  return I_value
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

function generateAction(Inputs)
  local action_taken
  if Policy[getHashPolicy(Inputs)]==nil then
    action_taken=torch.multinomial(torch.ones(1,math.pow(2,6)),1)
  else
    action_taken=torch.multinomial(torch.Tensor(Policy[getHashPolicy(Inputs)]),1)
  end
  return action_taken-1
end


function dead ()
  if memory.readbyte(0x000E) == 0x0B or memory.readbyte(0x000E) == 0x06 then
    return true;
  else
    return false;
  end
end

function run_episode()
  local memory={}
  local state = {}
  while true do
    state=getInputs()
    joypad.set(player1,getButtonsForAction(generateAction(state)))
    memory[#memory+1]={state,generateAction(state)}
    print(generateAction(state))
    if dead() then
      emu.message("Dead")
      break
    end
    emu.frameadvance()
    local timeout=TIMEOUT
    while(getHashPolicy(getInputs())==getHashPolicy(state)) do
      emu.frameadvance()
      if timeout==0 then
        break;
      end
      timeout = timeout-1
    end
  end
  return memory
end


init()
run_episode()

-- while true do
--   printInput()
--   -- getPositions()
--   emu.message("X = " .. marioX ..", Y = " .. marioY)
--   if dead() then
--     emu.message("Dead")
--     savestate.load(level_start)
--   end
--   emu.frameadvance()
-- end
