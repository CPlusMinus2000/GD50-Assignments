--[[
    PauseState Class
    Author: Colin He
    hcolin88@gmail.com

    A state used to pause the game during gameplay.
    Triggered when 'P' is pressed while in the PlayState.
]]

PauseState = Class{__includes = BaseState}

--[[
    When we enter the pause state, we expect to receive all the information
    that the PlayState has to keep track of, including the bird, pipes, 
    as well as the score.
]]
function PauseState:enter(params)
    self.bird = params.bird
    self.pipePairs = params.pipePairs
    self.score = params.score

    -- stop scrolling and pause music
    scrolling = false
    sounds['music']:pause()
    sounds['pause']:play()
end

function PauseState:update(dt)
    -- go back to play if 'P' is pressed
    if love.keyboard.wasPressed('P') or love.keyboard.wasPressed('p') then
        sounds['music']:resume()
        gStateMachine:change('play', {
            bird = self.bird,
            pipePairs = self.pipePairs,
            score = self.score
        })
    end
end

function PauseState:render()
    for k, pair in pairs(self.pipePairs) do
        pair:render()
    end

    love.graphics.setFont(flappyFont)
    love.graphics.print('Score: ' .. tostring(self.score), 8, 8)

    self.bird:render()

    love.graphics.setFont(hugeFont)
    love.graphics.print('ll', VIRTUAL_WIDTH / 2 - 6, VIRTUAL_HEIGHT / 2 - 28)
end