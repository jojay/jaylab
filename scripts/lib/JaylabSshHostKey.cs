using System;
using Renci.SshNet.Common;

public sealed class JaylabSshHostKey
{
    private readonly string expected;
    public string ObservedFingerprint { get; private set; }
    public string ObservedFingerprintMD5 { get; private set; }
    public bool Matched { get; private set; }

    public JaylabSshHostKey(string expectedFingerprint)
    {
        expected = expectedFingerprint;
    }

    public void Verify(object sender, HostKeyEventArgs args)
    {
        ObservedFingerprint = "SHA256:" + args.FingerPrintSHA256;
        ObservedFingerprintMD5 = "MD5:" + args.FingerPrintMD5;
        Matched = !string.IsNullOrEmpty(expected) &&
            string.Equals(expected, ObservedFingerprint, StringComparison.Ordinal);
        args.CanTrust = Matched;
    }
}
