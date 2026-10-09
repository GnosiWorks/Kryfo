package covertdtls

import (
	"errors"
	"github.com/pion/webrtc/v4"
	"github.com/theodorsm/covert-dtls/pkg/mimicry"
	"github.com/theodorsm/covert-dtls/pkg/randomize"
	"github.com/theodorsm/covert-dtls/pkg/utils"
)

func SetCovertDTLSSettings(config *CovertDTLSConfig, s *webrtc.SettingEngine) error {
	if config == nil && s == nil {
		return errors.New("nil pointers where passed to SetCovertDTLSSettings")
	}
	if config.Fingerprint != "" {
		mimic := &mimicry.MimickedClientHello{}
		err := mimic.LoadFingerprint(config.Fingerprint)
		if err != nil {
			return err
		}
		profiles := utils.DefaultSRTPProtectionProfiles()
		s.SetSRTPProtectionProfiles(profiles...)
		s.SetDTLSClientHelloMessageHook(mimic.Hook)
	} else if config.Mimic {
		mimic := &mimicry.MimickedClientHello{}
		if config.Randomize {
			err := mimic.LoadRandomFingerprint()
			if err != nil {
				return err
			}
		}
		profiles := utils.DefaultSRTPProtectionProfiles()
		s.SetSRTPProtectionProfiles(profiles...)
		s.SetDTLSClientHelloMessageHook(mimic.Hook)
	} else if config.Randomize {
		rand := randomize.RandomizedMessageClientHello{RandomALPN: true}
		s.SetDTLSClientHelloMessageHook(rand.Hook)
	}

	return nil
}
