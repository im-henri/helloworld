from Engine import Engine

if __name__ == "__main__":
    # Create a game engine
    screenSize = 80
    fpsCap = 120

    gameEngine = Engine((16*screenSize, 9*screenSize), fpsCap)

    # While loop that keeps everything running
    while gameEngine.running:
        gameEngine.mainLoop()

    # Quit when game engine is stopped
    gameEngine.quit()
