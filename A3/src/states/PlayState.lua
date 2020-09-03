--[[
    GD50
    Match-3 Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    State in which we can actually play, moving around a grid cursor that
    can swap two tiles; when two tiles make a legal swap (a swap that results
    in a valid match), perform the swap and destroy all matched tiles, adding
    their values to the player's point score. The player can continue playing
    until they exceed the number of points needed to get to the next level
    or until the time runs out, at which point they are brought back to the
    main menu or the score entry menu if they made the top 10.
]]

PlayState = Class{__includes = BaseState}

function PlayState:init()
    
    -- start our transition alpha at full, so we fade in
    self.transitionAlpha = 255

    -- position in the grid which we're highlighting
    self.boardHighlightX = 0
    self.boardHighlightY = 0

    -- timer used to switch the highlight rect's color
    self.rectHighlighted = false

    -- flag to show whether we're able to process input (not swapping or clearing)
    self.canInput = true

    -- tile we're currently highlighting (preparing to swap)
    self.highlightedTile = nil

    -- flag to check if curtain is down (and so needs rendering)
    self.curtainDown = false

    -- height of curtain (in case of no available matches)
    self.curtainY = -290

    self.score = 0
    self.timer = 60

    -- set our Timer class to turn cursor highlight on and off
    Timer.every(0.5, function()
        self.rectHighlighted = not self.rectHighlighted
    end)

    -- subtract 1 from timer every second
    Timer.every(1, function()
        self.timer = self.timer - 1

        -- play warning sound on timer if we get low
        if self.timer <= 5 then
            gSounds['clock']:play()
        end
    end)
end

function PlayState:enter(params)
    
    -- grab level # from the params we're passed
    self.level = params.level

    -- spawn a board and place it toward the right
    self.board = params.board or Board(VIRTUAL_WIDTH - 272, 16, self.level)

    -- grab score from params if it was passed
    self.score = params.score or 0

    -- score we have to reach to get to the next level
    self.scoreGoal = self.level * 1.25 * 1000

    -- check if matches exist in the board
    self.foundMatch = self.board:existMatches()
end

function PlayState:update(dt)
    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end

    -- go back to start if time runs out
    if self.timer <= 0 then
        
        -- clear timers from prior PlayStates
        Timer.clear()
        
        gSounds['game-over']:play()

        gStateMachine:change('game-over', {
            score = self.score
        })
    end

    -- go to next level if we surpass score goal
    if self.score >= self.scoreGoal then
        
        -- clear timers from prior PlayStates
        -- always clear before you change state, else next state's timers
        -- will also clear!
        Timer.clear()

        gSounds['next-level']:play()

        -- change to begin game state with new level (incremented)
        gStateMachine:change('begin-game', {
            level = self.level + 1,
            score = self.score
        })
    end

    -- if no possible matches were found, do a reshuffle
    if not self.foundMatch then
        self.curtainDown = true

        -- Start a transition of the curtain to the center of the screen
        Timer.tween(math.min(0.25, self.timer / 5), {
            [self] = {curtainY = -2}
        })
        
        -- after that, pause for a short bit with Timer.after,
        -- resetting the board during this interim
        :finish(function()
            while not self.foundMatch do
                self.board = Board(VIRTUAL_WIDTH - 272, 16, self.level)
                self.foundMatch = self.board:existMatches()
            end

            Timer.after(math.min(0.5, self.timer / 2.5), function()
                
                -- then, transition the curtain moving back up
                Timer.tween(math.min(0.25, self.timer / 5), {
                    [self] = {curtainY = -290}
                }):finish(function()
                    self.curtainDown = false
                end)
            end)
        end)
    end

    if self.canInput then
        -- move cursor around based on bounds of grid, playing sounds
        if love.keyboard.wasPressed('up') then
            self.boardHighlightY = math.max(0, self.boardHighlightY - 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('down') then
            self.boardHighlightY = math.min(7, self.boardHighlightY + 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('left') then
            self.boardHighlightX = math.max(0, self.boardHighlightX - 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('right') then
            self.boardHighlightX = math.min(7, self.boardHighlightX + 1)
            gSounds['select']:play()
        end

        -- if we've pressed enter, to select or deselect a tile...
        if love.keyboard.wasPressed('enter') or love.keyboard.wasPressed('return') then
            
            -- if same tile as currently highlighted, deselect
            local x = self.boardHighlightX + 1
            local y = self.boardHighlightY + 1
            
            -- if nothing is highlighted, highlight current tile
            if not self.highlightedTile then
                self.highlightedTile = self.board.tiles[y][x]

            -- if we select the position already highlighted, remove highlight
            elseif self.highlightedTile == self.board.tiles[y][x] then
                self.highlightedTile = nil

            -- if the difference between X and Y combined of this highlighted tile
            -- vs the previous is not equal to 1, also remove highlight
            elseif math.abs(self.highlightedTile.gridX - x) + math.abs(self.highlightedTile.gridY - y) > 1 then
                gSounds['error']:play()
                self.highlightedTile = nil
            else
                
                -- swap grid positions of tiles
                local tempX = self.highlightedTile.gridX
                local tempY = self.highlightedTile.gridY

                local newTile = self.board.tiles[y][x]

                self.highlightedTile.gridX = newTile.gridX
                self.highlightedTile.gridY = newTile.gridY
                newTile.gridX = tempX
                newTile.gridY = tempY

                -- swap tiles in the tiles table
                self.board.tiles[self.highlightedTile.gridY][self.highlightedTile.gridX] =
                    self.highlightedTile

                self.board.tiles[newTile.gridY][newTile.gridX] = newTile

                if not self.board:calculateMatches() then
                    -- illegal match
                    gSounds['error']:play()

                    -- swap back
                    tempX = self.highlightedTile.gridX
                    tempY = self.highlightedTile.gridY
                    self.highlightedTile.gridX = newTile.gridX
                    self.highlightedTile.gridY = newTile.gridY
                    newTile.gridX = tempX
                    newTile.gridY = tempY

                    -- swap tiles in the tiles table
                    self.board.tiles[self.highlightedTile.gridY][self.highlightedTile.gridX] =
                        self.highlightedTile

                    self.board.tiles[newTile.gridY][newTile.gridX] = newTile

                    self.highlightedTile = nil
                else 
                    -- tween coordinates between the two so they swap
                    Timer.tween(0.1, {
                        [self.highlightedTile] = {x = newTile.x, y = newTile.y},
                        [newTile] = {x = self.highlightedTile.x, y = self.highlightedTile.y}
                    })
                
                    -- once the swap is finished, we can tween falling blocks as needed
                    :finish(function()
                        self:calculateMatches()
                        self.foundMatch = self.board:existMatches()
                    end)
                end
            end
        
        elseif love.mouse.isDown(1) then

            -- get virtual position of mouse
            local x, y = love.mouse.getPosition()
            x, y = push:toGame(x, y)

            local tileX = math.floor((x - (VIRTUAL_WIDTH - 272)) / 32) + 1
            local tileY = math.floor((y - 16) / 32) + 1

            -- check that virtual position is on the board
            if tileX >= 1 and tileX <= 8 and tileY >= 1 and tileY <= 8 then
                -- if nothing is highlighted, highlight current tile
                if not self.highlightedTile then
                    self.highlightedTile = self.board.tiles[tileY][tileX]

                -- if we select the position already highlighted, remove highlight
                elseif self.highlightedTile == self.board.tiles[tileY][tileX] then
                    self.highlightedTile = nil

                -- if the difference between X and Y combined of this highlighted tile
                -- vs the previous is not equal to 1, also remove highlight
                elseif math.abs(self.highlightedTile.gridX - tileX) + math.abs(self.highlightedTile.gridY - tileY) > 1 then
                    gSounds['error']:play()
                    self.highlightedTile = nil
                else
                
                    -- swap grid positions of tiles
                    local tempX = self.highlightedTile.gridX
                    local tempY = self.highlightedTile.gridY

                    local newTile = self.board.tiles[tileY][tileX]

                    self.highlightedTile.gridX = newTile.gridX
                    self.highlightedTile.gridY = newTile.gridY
                    newTile.gridX = tempX
                    newTile.gridY = tempY

                    -- swap tiles in the tiles table
                    self.board.tiles[self.highlightedTile.gridY][self.highlightedTile.gridX] =
                        self.highlightedTile

                    self.board.tiles[newTile.gridY][newTile.gridX] = newTile

                    if not self.board:calculateMatches() then
                        -- illegal match
                        gSounds['error']:play()
    
                        -- swap back
                        tempX = self.highlightedTile.gridX
                        tempY = self.highlightedTile.gridY
                        self.highlightedTile.gridX = newTile.gridX
                        self.highlightedTile.gridY = newTile.gridY
                        newTile.gridX = tempX
                        newTile.gridY = tempY
    
                        -- swap tiles in the tiles table
                        self.board.tiles[self.highlightedTile.gridY][self.highlightedTile.gridX] =
                            self.highlightedTile
    
                        self.board.tiles[newTile.gridY][newTile.gridX] = newTile
    
                        self.highlightedTile = nil
                    else

                        -- tween coordinates between the two so they swap
                        Timer.tween(0.1, {
                            [self.highlightedTile] = {x = newTile.x, y = newTile.y},
                            [newTile] = {x = self.highlightedTile.x, y = self.highlightedTile.y}
                        })
                
                        -- once the swap is finished, we can tween falling blocks as needed
                        :finish(function()
                            self:calculateMatches()
                            self.foundMatch = self.board:existMatches()
                        end)
                    end
                end
            end
        end
    end

    Timer.update(dt)
end

-- helper function to detect tile membership
function tileInMatches(matches, tileToFind)
    for k, match in pairs(matches) do
        for l, tile in pairs(match) do
            if tile == tileToFind then
                return true
            end
        end
    end

    return false
end

--[[
    Calculates whether any matches were found on the board and tweens the needed
    tiles to their new destinations if so. Also removes tiles from the board that
    have matched and replaces them with new randomized tiles, deferring most of this
    to the Board class.
]]
function PlayState:calculateMatches()
    self.highlightedTile = nil

    -- if we have any matches, remove them and tween the falling blocks that result
    local matches = self.board:calculateMatches()
    
    if matches then
        gSounds['match']:stop()
        gSounds['match']:play()

        -- check for shiny tiles
        local shinyFound = false
        for k, match in pairs(matches) do
            for l, tile in pairs(match) do
                if tile.shiny then
                    shinyFound = true
                    
                    for gridX = 1, 8 do
                        if not tileInMatches(matches, self.board.tiles[tile.gridY][gridX]) then
                            table.insert(match, self.board.tiles[tile.gridY][gridX])
                        end
                    end
                end
            end
        end

        -- add score for each match
        for k, match in pairs(matches) do
            self.score = self.score + #match * 50
            self.timer = self.timer + 1

            for l, tile in pairs(match) do
                self.score = self.score + (tile.variety - 1) * 50
            end
        end

        -- remove any tiles that matched from the board, making empty spaces
        self.board:removeMatches()

        -- gets a table with tween values for tiles that should now fall
        local tilesToFall = self.board:getFallingTiles()

        -- tween new tiles that spawn from the ceiling over 0.25s to fill in
        -- the new upper gaps that exist
        Timer.tween(0.25, tilesToFall):finish(function()
            
            -- recursively call function in case new matches have been created
            -- as a result of falling blocks once new blocks have finished falling
            self:calculateMatches()
        end)
    
    -- if no matches, we can continue playing
    else
        self.canInput = true
    end
end

function PlayState:render()
    -- render board of tiles
    self.board:render()

    -- render highlighted tile if it exists
    if self.highlightedTile then
        
        -- multiply so drawing white rect makes it brighter
        love.graphics.setBlendMode('add')

        love.graphics.setColor(255, 255, 255, 96)
        love.graphics.rectangle('fill', (self.highlightedTile.gridX - 1) * 32 + (VIRTUAL_WIDTH - 272),
            (self.highlightedTile.gridY - 1) * 32 + 16, 32, 32, 4)

        -- back to alpha
        love.graphics.setBlendMode('alpha')
    end

    -- render highlight rect color based on timer
    if self.rectHighlighted then
        love.graphics.setColor(217, 87, 99, 255)
    else
        love.graphics.setColor(172, 50, 50, 255)
    end

    -- render curtain if it is down
    if self.curtainDown then
        love.graphics.draw(gTextures['curtain'], 222, self.curtainY)
        love.graphics.setColor(99, 155, 255, 255)
        love.graphics.setFont(gFonts['medium'])
        love.graphics.printf('Resetting...', 350, self.curtainY + 140, 182, 'center')
    end

    -- draw actual cursor rect
    love.graphics.setLineWidth(4)
    love.graphics.rectangle('line', self.boardHighlightX * 32 + (VIRTUAL_WIDTH - 272),
        self.boardHighlightY * 32 + 16, 32, 32, 4)

    -- GUI text
    love.graphics.setColor(56, 56, 56, 234)
    love.graphics.rectangle('fill', 16, 16, 186, 116, 4)

    love.graphics.setColor(99, 155, 255, 255)
    love.graphics.setFont(gFonts['medium'])
    love.graphics.printf('Level: ' .. tostring(self.level), 20, 24, 182, 'center')
    love.graphics.printf('Score: ' .. tostring(self.score), 20, 52, 182, 'center')
    love.graphics.printf('Goal : ' .. tostring(self.scoreGoal), 20, 80, 182, 'center')
    love.graphics.printf('Timer: ' .. tostring(self.timer), 20, 108, 182, 'center')
    -- love.graphics.printf(tostring(self.curtainDown), 20, 136, 182, 'center')

    --[[
    if self.foundMatch then
        love.graphics.printf(tostring(self.foundMatch[1]), 8, 164, 182, 'left')
        love.graphics.printf(tostring(self.foundMatch[2]), 28, 164, 182, 'left')
        love.graphics.printf(tostring(self.foundMatch[3]), 40, 164, 182, 'left')
        love.graphics.printf(tostring(self.foundMatch[4]), 56, 164, 182, 'left')
    end
    ]]
end