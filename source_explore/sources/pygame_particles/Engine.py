from typing import List
import pygame

from Particles import Particle, ParticleContainer
from GraphicsButton import GraphicsButton


class Engine:

    def __init__(self, screenSize, fpsCap):
        pygame.init()
        pygame.font.init()
        self.textFont = pygame.font.SysFont('Segoe UI Light', 55)

        self.fpsCap = fpsCap

        self.clock = pygame.time.Clock()
        self.window = pygame.display.set_mode(screenSize)
        self.running = True

        self._time = 0
        self._lastTime = 0
        self.deltaTime = 0

        self.fpsAve = -1
        self._fpsAveTemp = 0
        self.counterMax = 30
        self._counter = 0
        self.particleContainers: List[ParticleContainer] = []

        # GUI
        self.buttons = []
        for i in range(6):
            xSize = 125
            ySize = 75
            self.buttons.append(GraphicsButton((300 + i * (xSize + 5), 10), (xSize, ySize), (255, 0, 0), (0, 255, 0),
                                               self.event_guiButton, i, True))

        ''' lifetime, emissionOverLifetime, particleLifetimeMinMax, initialBurstMinMax, emissionSize,
        yVelMinMax, xVelMinMax, sizeMinMax, scaleByLifetimePercent = 0.75 '''
        self.particleContainerCreationInfo = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        self.buttons[0].pressed = True
        self.event_guiButton(0)

    @staticmethod
    def quit():
        pygame.quit()

    def fpsAverageCounter(self):
        if self._counter == self.counterMax:
            self.fpsAve = self._fpsAveTemp / (self.counterMax - 1)
            self._counter = 0
            self._fpsAveTemp = 0
        else:
            self._fpsAveTemp += (1 / self.deltaTime)

        self._counter += 1

    def mainLoop(self):
        self.clock.tick(self.fpsCap)
        # Get current time (for delta time purposes)
        self._time = pygame.time.get_ticks()

        self.update()

        # Events polling
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            elif event.type == pygame.KEYDOWN:
                self.event_keyDown(event)
            elif event.type == pygame.MOUSEBUTTONDOWN:
                self.event_mouseButtonDown()
            elif event.type == pygame.MOUSEMOTION:
                self.event_mouseMotion()

        # Draw call
        self.drawCall()

        # Create deltaTime to be used everywhere (Seconds)
        self.deltaTime = (self._time - self._lastTime) / 1000.0
        self._lastTime = self._time

        self.fpsAverageCounter()

    def event_keyDown(self, event):
        if event.key == pygame.K_ESCAPE:
            self.running = False

    def event_guiButton(self, buttonNumber):
        # Unpress other buttons
        for i in range(len(self.buttons)):
            if i != buttonNumber:
                self.buttons[i].unPress()

        ''' 
        0 = lifetime, 1 = emissionOverLifetime, 2 = particleLifetimeMinMax, 3 = initialBurstMinMax, 4 = emissionSize,
        5 = yVelMinMax, 6 =  xVelMinMax, 7 =  sizeMinMax, 8 = scaleByLifetimePercent, 9 = emission style
        10 = circularMaxVelocity, 11 = gravity
        '''
        if buttonNumber == 0:
            self.particleContainerCreationInfo[0] = 0.7
            self.particleContainerCreationInfo[1] = 25
            self.particleContainerCreationInfo[2] = (0.45, 2.5)
            self.particleContainerCreationInfo[3] = (10, 16)
            self.particleContainerCreationInfo[4] = 35
            self.particleContainerCreationInfo[5] = (-700, 100)
            self.particleContainerCreationInfo[6] = (-400, 400)
            self.particleContainerCreationInfo[7] = (7, 35)
            self.particleContainerCreationInfo[8] = 0.9
            self.particleContainerCreationInfo[9] = "Random"
            self.particleContainerCreationInfo[10] = 200
            self.particleContainerCreationInfo[11] = 9.81

        elif buttonNumber == 1:
            self.particleContainerCreationInfo[0] = 0.5
            self.particleContainerCreationInfo[1] = 350
            self.particleContainerCreationInfo[2] = (0.45, 1.6)
            self.particleContainerCreationInfo[3] = (20, 30)
            self.particleContainerCreationInfo[4] = 0
            self.particleContainerCreationInfo[5] = (-700, 100)
            self.particleContainerCreationInfo[6] = (-400, 400)
            self.particleContainerCreationInfo[7] = (7, 15)
            self.particleContainerCreationInfo[8] = 0.75
            self.particleContainerCreationInfo[9] = "Random"
            self.particleContainerCreationInfo[10] = 200
            self.particleContainerCreationInfo[11] = 9.81

        elif buttonNumber == 2:
            self.particleContainerCreationInfo[0] = 0.1
            self.particleContainerCreationInfo[1] = 250
            self.particleContainerCreationInfo[2] = (0.45, 2)
            self.particleContainerCreationInfo[3] = (10, 15)
            self.particleContainerCreationInfo[4] = 200
            self.particleContainerCreationInfo[5] = (-500, 100)
            self.particleContainerCreationInfo[6] = (-400, 400)
            self.particleContainerCreationInfo[7] = (7, 15)
            self.particleContainerCreationInfo[8] = 0.75
            self.particleContainerCreationInfo[9] = "Circle"
            self.particleContainerCreationInfo[10] = 700
            self.particleContainerCreationInfo[11] = 9.81

        elif buttonNumber == 3:
            self.particleContainerCreationInfo[0] = 0.3
            self.particleContainerCreationInfo[1] = 10
            self.particleContainerCreationInfo[2] = (0.35, 1.2)
            self.particleContainerCreationInfo[3] = (100, 150)
            self.particleContainerCreationInfo[4] = 100
            self.particleContainerCreationInfo[5] = (-700, 10)
            self.particleContainerCreationInfo[6] = (-40, 40)
            self.particleContainerCreationInfo[7] = (7, 15)
            self.particleContainerCreationInfo[8] = 0.5
            self.particleContainerCreationInfo[9] = "Random"
            self.particleContainerCreationInfo[10] = 200
            self.particleContainerCreationInfo[11] = 9.81

        elif buttonNumber == 4:
            self.particleContainerCreationInfo[0] = 0.3
            self.particleContainerCreationInfo[1] = 500
            self.particleContainerCreationInfo[2] = (0.45, 1.5)
            self.particleContainerCreationInfo[3] = (100, 200)
            self.particleContainerCreationInfo[4] = 100
            self.particleContainerCreationInfo[5] = (-9999, 9999)
            self.particleContainerCreationInfo[6] = (-9999, 9999)
            self.particleContainerCreationInfo[7] = (7, 15)
            self.particleContainerCreationInfo[8] = 0.8
            self.particleContainerCreationInfo[9] = "Circle"
            self.particleContainerCreationInfo[10] = 200
            self.particleContainerCreationInfo[11] = 25

        elif buttonNumber == 5:
            self.particleContainerCreationInfo[0] = 2
            self.particleContainerCreationInfo[1] = 500
            self.particleContainerCreationInfo[2] = (0.45, 2)
            self.particleContainerCreationInfo[3] = (0, 1)
            self.particleContainerCreationInfo[4] = 10
            self.particleContainerCreationInfo[5] = (-700, -600)
            self.particleContainerCreationInfo[6] = (-800, -700)
            self.particleContainerCreationInfo[7] = (7, 15)
            self.particleContainerCreationInfo[8] = 0.8
            self.particleContainerCreationInfo[9] = "Random"
            self.particleContainerCreationInfo[10] = 200
            self.particleContainerCreationInfo[11] = 9.81

    def event_mouseMotion(self):
        if len(self.particleContainers) != 0:
            self.particleContainers[-1].position = pygame.mouse.get_pos()

    def event_mouseButtonDown(self):
        pos = pygame.mouse.get_pos()

        buttonPress = False
        for b in self.buttons:
            buttonPress = b.collisionCheck(pos)
            if buttonPress:
                return

        # NOT GETTING HERE IF BUTTON IS PRESSED
        lifetime = self.particleContainerCreationInfo[0]
        emissionOverLifetime = self.particleContainerCreationInfo[1]
        particleLifetimeMinMax = self.particleContainerCreationInfo[2]
        initialBurstMinMax = self.particleContainerCreationInfo[3]
        position = pos
        emissionSize = self.particleContainerCreationInfo[4]
        yVelMinMax = self.particleContainerCreationInfo[5]
        xVelMinMax = self.particleContainerCreationInfo[6]
        sizeMinMax = self.particleContainerCreationInfo[7]
        scaleByLifetimePercent = self.particleContainerCreationInfo[8]
        emissionStyle = self.particleContainerCreationInfo[9]
        circularMaxVel = self.particleContainerCreationInfo[10]
        gravity = self.particleContainerCreationInfo[11]

        pc = ParticleContainer(lifetime, position, initialBurstMinMax, emissionOverLifetime, emissionSize,
                               yVelMinMax, xVelMinMax, particleLifetimeMinMax, sizeMinMax, scaleByLifetimePercent,
                               emissionStyle, circularMaxVel, gravity)

        self.particleContainers.append(pc)

    def drawCall(self):
        # Clear screen
        self.window.fill((0, 0, 0))

        # Draw
        for pc in self.particleContainers:
            for particle in pc.particles:
                pygame.draw.circle(self.window,
                                   particle.color,
                                   particle.positionInteger(),
                                   particle.sizeInteger())

        # FPS counter
        self.window.blit(self.textFont.render("FPS ave: {:.1f}".format(self.fpsAve), False, (255, 150, 50)), (0, 0))

        # GUI
        for b in self.buttons:
            pygame.draw.rect(self.window,
                             b.currentColor(),
                             b.rect)

        # Refresh display
        pygame.display.flip()

    def update(self):
        # Update every particle container and remove it when its done emitting
        for i in range(len(self.particleContainers) - 1, -1, -1):
            if not self.particleContainers[i].update(self.deltaTime):
                del (self.particleContainers[i])

        # print(len(self.particleContainers))
