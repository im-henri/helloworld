class GraphicsButton:
    def __init__(self, position, size, color1, color2, pressCall, buttonNumber, toggleable=False):
        self.rect = (position, size)
        self.colors = (color1, color2)
        self.toggleable = toggleable
        self.pressed = False
        self.pressCall = pressCall
        self.buttonNumber = buttonNumber

    def collisionCheck(self, pos):
        if self.rect[0][0] < pos[0] < self.rect[0][0] + self.rect[1][0]:
            if self.rect[0][1] < pos[1] < self.rect[0][1] + self.rect[1][1]:
                self.pressed = not self.pressed
                self.pressCall(self.buttonNumber)
                return True
        return False

    def unPress(self):
        if self.toggleable:
            self.pressed = False

    def currentColor(self):
        if self.toggleable is True and self.pressed is True:
            return self.colors[1]
        else:
            return self.colors[0]
