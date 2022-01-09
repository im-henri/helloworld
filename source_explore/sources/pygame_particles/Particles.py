import random
from math import floor, sin, cos
from typing import List


class Particle:
    def __init__(self, position, velocity, lifetime, size, color, scaleByLifetimePercent, gravity=9.81):
        self.position = position
        self.velocity = velocity
        self.lifetime = lifetime
        self._initialLifeTime = lifetime
        self.size = size
        self._initialSize = size
        self.color = color
        self.gravity = gravity

        self.scaleByLifetimePercent = scaleByLifetimePercent

    def positionInteger(self):
        return int(self.position[0]), int(self.position[1])

    def sizeInteger(self):
        return int(self.size)

    def update(self, dt, ):
        """
        Updates position of particle, w.r.t. delta time.
        :param dt:
        :return: Boolean: True if still alive, otherwise False.
        """

        lifetimePercent = 1 - (self.lifetime / self._initialLifeTime)
        # Int because pygame cant draw float size
        self.size = self._initialSize - int(lifetimePercent * self._initialSize * self.scaleByLifetimePercent)

        self.velocity[1] += self.gravity

        self.position[0] += self.velocity[0] * dt
        self.position[1] += self.velocity[1] * dt

        self.lifetime -= dt

        if self.lifetime <= 0:
            return False
        else:
            return True


class ParticleContainer:
    def __init__(self, lifetime, position, initialBurstMinMax, emissionOverLifetime: int, emissionSize,
                 yVelMinMax, xVelMinMax,
                 lifetimeMinMax, sizeMinMax, scaleByLifetimePercent,
                 emissionStyle: str = "Random", circleEmissionMaxVelocity: int = 0, gravity=9.81):
        self.particles: List[Particle] = []
        self.lifetime = lifetime
        self._initialLifeTime = lifetime
        self.position = position
        self.emissionOverLifetime = emissionOverLifetime
        self.emissionSize = emissionSize
        self.yVelMinMax = yVelMinMax
        self.xVelMinMax = xVelMinMax
        self.lifetimeMinMax = lifetimeMinMax
        self.sizeMinMax = sizeMinMax
        self.scaleByLifetimePercent = scaleByLifetimePercent
        self.gravity = gravity

        # Emission style specific variables
        self.emissionStyle = 0
        if emissionStyle == "Random":
            self.emissionStyle = 0
        elif emissionStyle == "Circle":
            self.emissionStyle = 1
            if circleEmissionMaxVelocity == 0:
                self.circleEmissionMaxVelocity = max([abs(self.yVelMinMax[0]), abs(self.yVelMinMax[0]),
                                                      abs(self.xVelMinMax[0]), abs(self.xVelMinMax[0])])
            else:
                self.circleEmissionMaxVelocity = circleEmissionMaxVelocity

        # Do a single initial burst
        self.burst(initialBurstMinMax)

        # Emission happens over the lifetime
        self.emitCount: int = emissionOverLifetime
        self._emitted = 0
        self.emissionDone = False

    def _createParticle(self):
        if self.emissionStyle == 0:
            rdmOffset = int(self.emissionSize / 2)

            xOffset = 0 if self.emissionSize == 0 else random.randrange(-rdmOffset, rdmOffset, 1)
            yOffset = 0 if self.emissionSize == 0 else random.randrange(-rdmOffset, rdmOffset, 1)
            xVel = random.randrange(self.xVelMinMax[0] * 100, self.xVelMinMax[1] * 100, 1) / 100
            yVel = random.randrange(self.yVelMinMax[0] * 100, self.yVelMinMax[1] * 100, 1) / 100

        else:
            angle = random.randrange(0, 628318, 1)/100000
            sinus = sin(angle)
            cosine = cos(angle)

            xOffset = self.emissionSize / 2 * sinus
            yOffset = self.emissionSize / 2 * cosine

            xVel = sinus * self.circleEmissionMaxVelocity
            yVel = cosine * self.circleEmissionMaxVelocity

        size = round(self.sizeMinMax[0]) if self.sizeMinMax[0] == self.sizeMinMax[1] \
            else random.randrange(round(self.sizeMinMax[0]), round(self.sizeMinMax[1]), 1)

        particlePos = [self.position[0] + xOffset, self.position[1] + yOffset]
        particleVel = [xVel, yVel]
        particleLifetime = random.randrange(round(self.lifetimeMinMax[0] * 1000),
                                            round(self.lifetimeMinMax[1] * 1000), 1) / 1000
        particleSize = size
        particleColor = (random.randrange(0, 255, 1),
                         random.randrange(0, 255, 1),
                         random.randrange(0, 255, 1))

        return Particle(particlePos, particleVel, particleLifetime, particleSize, particleColor,
                        self.scaleByLifetimePercent, self.gravity)

    def emit(self, lifetimePercent):
        # TODO Add proper parameters
        if lifetimePercent >= 1:
            self.emissionDone = True

        toEmitCount = floor(self.emitCount * lifetimePercent) - self._emitted
        self._emitted += toEmitCount

        for i in range(toEmitCount):
            self.particles.append(self._createParticle())

    def burst(self, minMax):
        particleList = []
        for i in range(random.randrange(minMax[0], minMax[1])):
            particle = self._createParticle()
            particleList.append(particle)

        # Append to the container
        self.particles.extend(particleList)

    def update(self, deltaTime):
        """
        Updates all the particles inside the container.
        Returns True when still emitting/particles alive. Otherwise False
        :param deltaTime:
        :return: Boolean:
        """

        for i in range(len(self.particles) - 1, -1, -1):
            if not self.particles[i].update(deltaTime):
                del (self.particles[i])

        if not self.emissionDone:
            lifetimePercent = 1 - (self.lifetime / self._initialLifeTime)
            self.emit(lifetimePercent)

        self.lifetime -= deltaTime

        if self.lifetime <= 0 and len(self.particles) == 0:
            return False
        else:
            return True

    def __iter__(self):
        return iter(self.particles)

    def __str__(self):
        return str(self.particles)
