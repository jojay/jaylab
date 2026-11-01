using System;
using System.Net.Http;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

public sealed class JaylabTlsObservation
{
    public string Address { get; set; }
    public int Port { get; set; }
    public string Sha256 { get; set; }
    public string Subject { get; set; }
    public string Issuer { get; set; }
    public DateTime NotBeforeUtc { get; set; }
    public DateTime NotAfterUtc { get; set; }
    public string PolicyErrors { get; set; }
    public string ErrorType { get; set; }
    public byte[] PublicCertificate { get; set; }
}

public sealed class JaylabTlsCertificate
{
    private readonly string address;
    private readonly int port;
    private readonly string expected;

    public JaylabTlsCertificate(string expectedAddress, int expectedPort, string expectedSha256)
    {
        address = expectedAddress;
        port = expectedPort;
        expected = expectedSha256;
    }

    public bool VerifyHttp(HttpRequestMessage request, X509Certificate2 certificate,
                           X509Chain chain, SslPolicyErrors errors)
    {
        if (certificate == null || request.RequestUri == null) return false;
        return request.RequestUri.Scheme == "https" &&
            request.RequestUri.Host == address && request.RequestUri.Port == port &&
            DateTime.UtcNow >= certificate.NotBefore.ToUniversalTime() &&
            DateTime.UtcNow <= certificate.NotAfter.ToUniversalTime() &&
            !string.IsNullOrEmpty(expected) &&
            string.Equals(certificate.GetCertHashString(HashAlgorithmName.SHA256),
                          expected, StringComparison.OrdinalIgnoreCase);
    }

    public static JaylabTlsObservation Probe(string address, int port)
    {
        var result = new JaylabTlsObservation { Address = address, Port = port };
        using (var tcp = new TcpClient())
        {
            try
            {
                if (!tcp.ConnectAsync(address, port).Wait(3000))
                {
                    result.ErrorType = "ConnectTimeout";
                    return result;
                }
                tcp.ReceiveTimeout = 5000;
                tcp.SendTimeout = 5000;
                using (var tls = new SslStream(tcp.GetStream(), false, (sender, certificate, chain, errors) =>
                {
                    var cert = certificate as X509Certificate2;
                    if (cert != null)
                    {
                        result.Sha256 = cert.GetCertHashString(HashAlgorithmName.SHA256);
                        result.Subject = cert.Subject;
                        result.Issuer = cert.Issuer;
                        result.NotBeforeUtc = cert.NotBefore.ToUniversalTime();
                        result.NotAfterUtc = cert.NotAfter.ToUniversalTime();
                        result.PolicyErrors = errors.ToString();
                        result.PublicCertificate = cert.Export(X509ContentType.Cert);
                    }
                    // Observation only: reject every certificate, never authenticate.
                    return false;
                }))
                {
                    tls.AuthenticateAsClient(new SslClientAuthenticationOptions {
                        TargetHost = address,
                        EnabledSslProtocols = SslProtocols.Tls12 | SslProtocols.Tls13
                    });
                }
            }
            catch (Exception error)
            {
                if (result.Sha256 == null) result.ErrorType = error.GetBaseException().GetType().Name;
            }
        }
        return result;
    }
}
