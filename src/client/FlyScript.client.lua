-- Press "X" to toggle fly
-- Don't question where I got this from, I found it and it is poorly made, but works. I didn't feel like making my own : (
    local function toggle()
        shared.flyEnabled = not shared.flyEnabled
        if shared.flyEnabled then
            local plr = game.Players.LocalPlayer
            local mouse = plr:GetMouse()
    
            local localplayer = plr
    
            if workspace:FindFirstChild("Core") then
                workspace.Core:Destroy()
            end
    
            local Core = Instance.new("Part")
            Core.Name = "Core"
            Core.Size = Vector3.new(0.05, 0.05, 0.05)
    
            spawn(function()
                Core.Parent = workspace
                local Weld = Instance.new("Weld", Core)
                Weld.Part0 = Core
                Weld.Part1 = localplayer.Character:FindFirstChild("LowerTorso") or localplayer.Character:FindFirstChild("Torso")
                Weld.C0 = CFrame.new(0, 0, 0)
            end)
    
            workspace:WaitForChild("Core")
    
            local torso = workspace.Core
            flying = true
            local speed = 20
            local keys = {
                a = false,
                d = false,
                w = false,
                s = false
            }
            local e1
            local e2
            local function start()
                local pos = Instance.new("BodyPosition", torso)
                local gyro = Instance.new("BodyGyro", torso)
                pos.Name = "EPIXPOS"
                pos.maxForce = Vector3.new(math.huge, math.huge, math.huge)
                pos.position = torso.Position
                gyro.maxTorque = Vector3.new(9e9, 9e9, 9e9)
                gyro.cframe = torso.CFrame
                repeat
                    wait()
                    localplayer.Character.Humanoid.PlatformStand = true
                    local new = gyro.cframe - gyro.cframe.p + pos.position
                    if not keys.w and not keys.s and not keys.a and not keys.d then
                        speed = 20
                    end
                    if keys.w then
                        new = new + workspace.CurrentCamera.CoordinateFrame.lookVector * speed
                        speed = speed + 0
                    end
                    if keys.s then
                        new = new - workspace.CurrentCamera.CoordinateFrame.lookVector * speed
                        speed = speed + 0
                    end
                    if keys.d then
                        new = new * CFrame.new(speed, 0, 0)
                        speed = speed + 0
                    end
                    if keys.a then
                        new = new * CFrame.new(-speed, 0, 0)
                        speed = speed + 0
                    end
                    if speed > 10 then
                        speed = 20
                    end
                    pos.position = new.p
                    if keys.w then
                        gyro.cframe = workspace.CurrentCamera.CoordinateFrame * CFrame.Angles(-math.rad(speed * 0), 0, 0)
                    elseif keys.s then
                        gyro.cframe = workspace.CurrentCamera.CoordinateFrame * CFrame.Angles(math.rad(speed * 0), 0, 0)
                    else
                        gyro.cframe = workspace.CurrentCamera.CoordinateFrame
                    end
                until flying == false
                if gyro then
                    gyro:Destroy()
                end
                if pos then
                    pos:Destroy()
                end
                flying = false
                localplayer.Character.Humanoid.PlatformStand = false
                speed = 20
            end
            e1 = mouse.KeyDown:connect(function(key)
                if not torso or not torso.Parent then
                    flying = false
                    e1:disconnect()
                    e2:disconnect()
                    return
                end
                if key == "w" then
                    keys.w = true
                elseif key == "s" then
                    keys.s = true
                elseif key == "a" then
                    keys.a = true
                elseif key == "d" then
                    keys.d = true
                elseif key == "x" then
                    if flying == true then
                        flying = false
                    else
                        flying = true
                        start()
                    end
                end
            end)
            e2 = mouse.KeyUp:connect(function(key)
                if key == "w" then
                    keys.w = false
                elseif key == "s" then
                    keys.s = false
                elseif key == "a" then
                    keys.a = false
                elseif key == "d" then
                    keys.d = false
                end
            end)
            start()
        end
    end
    
    game:GetService("UserInputService").InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == Enum.KeyCode.X then
            toggle()
        end
    end)