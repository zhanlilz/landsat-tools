class Scene(object):

    def __init__(self, name, files=None):
        self.name = name
        self.files = []

        if isinstance(files, basestring):
            self.add(files)
        elif isinstance(files, list):
            for f in files:
                self.add(f)

    def add(self, f):
        self.files.append(f)

    def __str__(self):
        return self.name


class Scenes(object):

    def __init__(self, scenes=[]):
        self.scenes_dict = {}
        self.scenes_list = []
        for scene in scenes:
            self.add(self.validate(scene))

    def __getitem__(self, key):
        if isinstance(key, int):
            return self.scenes_list[key]
        elif isinstance(key, str):
            return self.scenes_dict[key]
        else:
            raise Exception('Key is not supported.')

    def __setitem__(self, key, value):
        if isinstance(key, int):
            self.scenes_list[key] = self.validate(value)
        elif isinstance(key, str):
            self.scenes_dict[key] = self.validate(value)
        else:
            raise Exception('Key is not supported.')

    def __delitem__(self, key):
        if isinstance(key, int):
            del self.scenes_dict[self.scenes[key]]
            del self.scenes_list[key]
        elif isinstance(key, str):
            del self.scenes_list[self.scenes.index(key)]
            del self.scenes_dict[key]
        else:
            raise Exception('Key is not supported.')

    def __len__(self):
        return len(self.scenes_dict.keys())

    def __str__(self):
        return '[Scenes]: Includes {0:d} scenes'.format(len(self))

    def add(self, scene):
        self.scenes_list.append(self.validate(scene))
        self.scenes_dict[scene.name] = scene

    def validate(self, scene):
        if not isinstance(scene, Scene):
            raise Exception('scene must be an instance of Scene')
        return scene

    def clear(self):
        self.scenes_list = []
        self.scenes_dict = {}
        
    @property
    def scenes(self):
        return [s.name for s in self]
