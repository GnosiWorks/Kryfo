package proxy

import (
	"context"
	"errors"
	"log"
	"net"
	"net/url"
	"strconv"
	"time"

	"github.com/miekg/dns"
	"github.com/pion/transport/v4"
	"github.com/txthinking/socks5"
)

func NewSocks5UDPClient(addr *url.URL) SocksClient {
	return SocksClient{addr: addr}
}

type SocksClient struct {
	addr *url.URL
}

type SocksConn struct {
	net.Conn
	socks5Client *socks5.Client
}

func (s SocksConn) SetReadBuffer(bytes int) error {
	return nil
}

func (s SocksConn) SetWriteBuffer(bytes int) error {
	return nil
}

func (s SocksConn) ReadFromUDP(b []byte) (n int, addr *net.UDPAddr, err error) {
	var buf [2000]byte
	n, err = s.Conn.Read(buf[:])
	if err != nil {
		return 0, nil, err
	}
	Datagram, err := socks5.NewDatagramFromBytes(buf[:n])
	if err != nil {
		return 0, nil, err
	}
	addr, err = net.ResolveUDPAddr("udp", Datagram.Address())
	if err != nil {
		return 0, nil, err
	}
	n = copy(b, Datagram.Data)
	if n < len(Datagram.Data) {
		return 0, nil, errors.New("short buffer")
	}
	return len(Datagram.Data), addr, nil
}

func (s SocksConn) ReadMsgUDP(b, oob []byte) (n, oobn, flags int, addr *net.UDPAddr, err error) {
	panic("unimplemented")
}

func (s SocksConn) WriteToUDP(b []byte, addr *net.UDPAddr) (int, error) {

	a, addrb, portb, err := socks5.ParseAddress(addr.String())
	if err != nil {
		return 0, err
	}
	packet := socks5.NewDatagram(a, addrb, portb, b)
	_, err = s.Conn.Write(packet.Bytes())
	if err != nil {
		return 0, err
	}
	return len(b), nil
}

func (s SocksConn) WriteMsgUDP(b, oob []byte, addr *net.UDPAddr) (n, oobn int, err error) {
	panic("unimplemented")
}

func (sc *SocksClient) ListenPacket(network string, locAddr *net.UDPAddr) (transport.UDPConn, error) {
	conn, err := sc.listenPacket()
	if err != nil {
		log.Println("[SOCKS5 Client Error] cannot listen packet", err)
	}
	return conn, err
}

func (sc *SocksClient) listenPacket() (transport.UDPConn, error) {
	var username, password string
	if sc.addr.User != nil {
		username = sc.addr.User.Username()
		password, _ = sc.addr.User.Password()
	}
	client, err := socks5.NewClient(
		sc.addr.Host,
		username, password, 300, 300)
	if err != nil {
		return nil, err
	}

	err = client.Negotiate(nil)
	if err != nil {
		return nil, err
	}

	udpRequest := socks5.NewRequest(socks5.CmdUDP, socks5.ATYPIPv4, []byte{0x00, 0x00, 0x00, 0x00}, []byte{0x00, 0x00})

	reply, err := client.Request(udpRequest)
	if err != nil {
		return nil, err
	}

	udpServerAddr := socks5.ToAddress(reply.Atyp, reply.BndAddr, reply.BndPort)

	conn, err := net.Dial("udp", udpServerAddr)
	if err != nil {
		return nil, err
	}

	return &SocksConn{conn, client}, nil
}

func (s SocksConn) WriteTo(p []byte, addr net.Addr) (n int, err error) {
	return s.WriteToUDP(p, addr.(*net.UDPAddr))
}

func (s SocksConn) ReadFrom(p []byte) (n int, addr net.Addr, err error) {
	return s.ReadFromUDP(p)
}

func (s SocksConn) Read(b []byte) (int, error) {
	panic("implement me")
}

func (s SocksConn) RemoteAddr() net.Addr {
	panic("implement me")
}

func (s SocksConn) Write(b []byte) (int, error) {
	panic("implement me")
}

func (sc *SocksClient) ResolveUDPAddr(network string, address string) (*net.UDPAddr, error) {
	dnsServer, err := net.ResolveUDPAddr("udp", "1.1.1.1:53")
	if err != nil {
		return nil, err
	}
	proxiedResolver := newDnsResolver(sc, dnsServer)
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()
	host, port, err := net.SplitHostPort(address)
	if err != nil {
		return nil, err
	}
	ip, err := proxiedResolver.lookupIPAddr(ctx, host, network == "udp6")
	if err != nil {
		return nil, err
	}
	if len(ip) <= 0 {
		return nil, errors.New("cannot resolve hostname: NXDOMAIN")
	}
	switch network {
	case "udp4":
		var v4IPAddr []net.IPAddr
		for _, v := range ip {
			if v.IP.To4() != nil {
				v4IPAddr = append(v4IPAddr, v)
			}
		}
		ip = v4IPAddr
	case "udp6":
		var v6IPAddr []net.IPAddr
		for _, v := range ip {
			if v.IP.To4() == nil {
				v6IPAddr = append(v6IPAddr, v)
			}
		}
		ip = v6IPAddr
	case "udp":
	default:
		return nil, errors.New("unknown network")
	}

	if len(ip) <= 0 {
		return nil, errors.New("cannot resolve hostname: so suitable address")
	}

	portInInt, err := strconv.ParseInt(port, 10, 32)
	return &net.UDPAddr{
		IP:   ip[0].IP,
		Port: int(portInInt),
		Zone: "",
	}, nil
}

func newDnsResolver(sc *SocksClient,
	serverAddress net.Addr) *dnsResolver {
	return &dnsResolver{sc: sc, serverAddress: serverAddress}
}

type dnsResolver struct {
	sc            *SocksClient
	serverAddress net.Addr
}

func (r *dnsResolver) lookupIPAddr(ctx context.Context, host string, ipv6 bool) ([]net.IPAddr, error) {
	packetConn, err := r.sc.listenPacket()
	if err != nil {
		return nil, err
	}
	msg := new(dns.Msg)
	if !ipv6 {
		msg.SetQuestion(dns.Fqdn(host), dns.TypeA)
	} else {
		msg.SetQuestion(dns.Fqdn(host), dns.TypeAAAA)
	}
	encodedMsg, err := msg.Pack()
	if err != nil {
		log.Println(err.Error())
	}
	for i := 2; i >= 0; i-- {
		_, err := packetConn.WriteTo(encodedMsg, r.serverAddress)
		if err != nil {
			log.Println(err.Error())
		}
	}
	ctx, cancel := context.WithTimeout(ctx, time.Second)
	defer cancel()
	go func() {
		<-ctx.Done()
		packetConn.Close()
	}()
	var dataBuf [1600]byte
	n, _, err := packetConn.ReadFrom(dataBuf[:])
	if err != nil {
		return nil, err
	}
	err = msg.Unpack(dataBuf[:n])
	if err != nil {
		return nil, err
	}
	var returnedIPs []net.IPAddr
	for _, resp := range msg.Answer {
		switch respTyped := resp.(type) {
		case *dns.A:
			returnedIPs = append(returnedIPs, net.IPAddr{IP: respTyped.A})
		case *dns.AAAA:
			returnedIPs = append(returnedIPs, net.IPAddr{IP: respTyped.AAAA})
		}
	}
	return returnedIPs, nil
}

func NewTransportWrapper(sc *SocksClient, innerNet transport.Net) transport.Net {
	return &transportWrapper{sc: sc, Net: innerNet}
}

type transportWrapper struct {
	transport.Net
	sc *SocksClient
}

func (t *transportWrapper) ListenUDP(network string, locAddr *net.UDPAddr) (transport.UDPConn, error) {
	return t.sc.ListenPacket(network, nil)
}

func (t *transportWrapper) ListenPacket(network string, address string) (net.PacketConn, error) {
	return t.sc.ListenPacket(network, nil)
}

func (t *transportWrapper) ResolveUDPAddr(network string, address string) (*net.UDPAddr, error) {
	return t.sc.ResolveUDPAddr(network, address)
}
