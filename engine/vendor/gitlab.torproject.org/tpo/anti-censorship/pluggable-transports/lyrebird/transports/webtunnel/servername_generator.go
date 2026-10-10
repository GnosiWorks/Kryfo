package webtunnel

import (
	"errors"
	"strings"
	"sync"

	"gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird/common/csrand"
)

var ERRInvalidSpec = errors.New("invalid servername spec")

func newServerNameGenerator(spec string) (*serverNameGenerator, error) {
	generator := &serverNameGenerator{
		spec: spec,
	}

	if err := generator.parse(); err != nil {
		return nil, err
	}

	generator.currentPosition = csrand.Intn(len(generator.servername))

	return generator, nil
}

type serverNameGenerator struct {
	spec string

	servername []string

	currentPosition int

	lock sync.Mutex
}

func (s *serverNameGenerator) parse() error {
	if len(s.spec) == 0 {
		return nil
	}

	// Split the spec by commas to get the server names.
	s.servername = []string{}
	for _, name := range strings.Split(s.spec, ",") {
		name = strings.TrimSpace(name)
		if len(name) > 0 {
			s.servername = append(s.servername, name)
		}
	}

	if len(s.servername) == 0 {
		return ERRInvalidSpec
	}

	return nil
}

func (s *serverNameGenerator) GenerateServerName() string {
	s.lock.Lock()
	defer s.lock.Unlock()

	return s.generateServerNameWithoutLock()
}

func (s *serverNameGenerator) generateServerNameWithoutLock() string {
	if len(s.servername) == 0 {
		return s.spec
	}
	// Generate a random server name from the list.
	return s.servername[s.currentPosition]
}

func (s *serverNameGenerator) RerollIfServerNameCandidateNotChanged(currentServerName string) {
	s.lock.Lock()
	defer s.lock.Unlock()

	if len(s.servername) == 0 {
		return
	}

	if s.generateServerNameWithoutLock() != currentServerName {
		return
	}

	// Move to the next server name in the list.
	s.currentPosition = (s.currentPosition + 1) % len(s.servername)
}

func newServerNameGeneratorHolder() (*serverNameGeneratorHolder, error) {
	return &serverNameGeneratorHolder{
		generators: make(map[string]*serverNameGenerator),
	}, nil
}

type serverNameGeneratorHolder struct {
	lock       sync.Mutex
	generators map[string]*serverNameGenerator
}

func (h *serverNameGeneratorHolder) GetGenerator(spec string) (*serverNameGenerator, error) {
	h.lock.Lock()
	defer h.lock.Unlock()

	if generator, ok := h.generators[spec]; ok {
		return generator, nil
	}

	generator, err := newServerNameGenerator(spec)
	if err != nil {
		return nil, err
	}

	h.generators[spec] = generator
	return generator, nil
}
