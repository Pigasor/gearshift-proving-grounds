# Puts the game's icon and name into a Windows exe (a copy of the Godot runtime): replaces the icon
# resources and the version info (ProductName / FileDescription), so Explorer, the taskbar and its
# right-click menu show "GearShift JoyDrive!" and the G logo instead of Godot.
# Uses the Windows resource API (UpdateResource) - nothing to download.
# Usage: brand_exe.ps1 -Exe <path> -Ico <path> -Name <text> [-Version 0.1.0.0]
param([Parameter(Mandatory)] [string]$Exe, [Parameter(Mandatory)] [string]$Ico, [Parameter(Mandatory)] [string]$Name, [string]$Version = "0.1.0.0", [string]$Company = "Pigasor")
$ErrorActionPreference = "Stop"

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public static class ExeBrand {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr LoadLibraryEx(string f, IntPtr h, uint flags);
    [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr h);
    delegate bool EnumNameProc(IntPtr h, IntPtr type, IntPtr name, IntPtr param);
    delegate bool EnumLangProc(IntPtr h, IntPtr type, IntPtr name, ushort lang, IntPtr param);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool EnumResourceNames(IntPtr h, IntPtr type, EnumNameProc cb, IntPtr p);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool EnumResourceLanguages(IntPtr h, IntPtr type, IntPtr name, EnumLangProc cb, IntPtr p);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr BeginUpdateResource(string f, bool del);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern bool UpdateResource(IntPtr h, IntPtr type, IntPtr name, ushort lang, byte[] data, uint size);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool EndUpdateResource(IntPtr h, bool discard);

    const int RT_ICON = 3, RT_GROUP_ICON = 14, RT_VERSION = 16;

    class Res { public object Name; public ushort Lang; }

    static List<Res> List(IntPtr mod, int type) {
        var res = new List<Res>();
        EnumResourceNames(mod, (IntPtr)type, (h, t, n, p) => {
            object name = ((long)n >> 16) == 0 ? (object)(int)(long)n : Marshal.PtrToStringUni(n);
            EnumResourceLanguages(mod, (IntPtr)type, n, (h2, t2, n2, lang, p2) => { res.Add(new Res { Name = name, Lang = lang }); return true; }, IntPtr.Zero);
            return true;
        }, IntPtr.Zero);
        return res;
    }

    static IntPtr NamePtr(object name) {
        return name is int ? (IntPtr)(int)name : Marshal.StringToHGlobalUni((string)name);
    }

    static void Pad(BinaryWriter w) { while (w.BaseStream.Position % 4 != 0) w.Write((byte)0); }

    // VS_VERSIONINFO style block: wLength, wValueLength, wType, key, padding, value, padding, children
    static byte[] Block(string key, byte[] value, int valueLen, ushort type, List<byte[]> children) {
        var ms = new MemoryStream(); var w = new BinaryWriter(ms);
        w.Write((ushort)0); w.Write((ushort)valueLen); w.Write(type);
        w.Write(Encoding.Unicode.GetBytes(key + "\0"));
        Pad(w);
        if (value != null) w.Write(value);
        if (children != null) foreach (var c in children) { Pad(w); w.Write(c); }
        var b = ms.ToArray();
        BitConverter.GetBytes((ushort)b.Length).CopyTo(b, 0);
        return b;
    }

    static byte[] VersionInfo(string name, string company, string file, ushort[] v) {
        var fixd = new MemoryStream(); var f = new BinaryWriter(fixd);
        uint ms = (uint)(v[0] << 16 | v[1]), ls = (uint)(v[2] << 16 | v[3]);
        f.Write(0xFEEF04BDu); f.Write(0x00010000u); f.Write(ms); f.Write(ls); f.Write(ms); f.Write(ls);
        f.Write(0x3Fu); f.Write(0u); f.Write(0x40004u); f.Write(1u); f.Write(0u); f.Write(0u); f.Write(0u);
        string ver = string.Join(".", v);
        var strings = new List<byte[]>();
        foreach (var kv in new[] {
            new[] {"CompanyName", company}, new[] {"FileDescription", name}, new[] {"FileVersion", ver},
            new[] {"InternalName", name}, new[] {"LegalCopyright", "(c) " + company}, new[] {"OriginalFilename", file},
            new[] {"ProductName", name}, new[] {"ProductVersion", ver} }) {
            byte[] val = Encoding.Unicode.GetBytes(kv[1] + "\0");
            strings.Add(Block(kv[0], val, kv[1].Length + 1, 1, null));
        }
        var table = Block("040904B0", null, 0, 1, strings);
        var sfi = Block("StringFileInfo", null, 0, 1, new List<byte[]> { table });
        var tr = Block("Translation", BitConverter.GetBytes(0x04B00409u), 4, 0, null);
        var vfi = Block("VarFileInfo", null, 0, 1, new List<byte[]> { tr });
        return Block("VS_VERSION_INFO", fixd.ToArray(), 52, 0, new List<byte[]> { sfi, vfi });
    }

    public static void Apply(string exe, string ico, string name, string company, string version) {
        IntPtr mod = LoadLibraryEx(exe, IntPtr.Zero, 0x2 /* LOAD_LIBRARY_AS_DATAFILE */);
        if (mod == IntPtr.Zero) throw new Exception("cannot open " + exe);
        var icons = List(mod, RT_ICON); var groups = List(mod, RT_GROUP_ICON); var versions = List(mod, RT_VERSION);
        FreeLibrary(mod);

        byte[] icoData = File.ReadAllBytes(ico);
        int count = BitConverter.ToUInt16(icoData, 4);
        IntPtr h = BeginUpdateResource(exe, false);
        if (h == IntPtr.Zero) throw new Exception("BeginUpdateResource failed " + Marshal.GetLastWin32Error());
        // (the old icon images stay, unused: deleting them made UpdateResource fail on this exe)
        int firstId = 1;
        foreach (var r in icons) if (r.Name is int && (int)r.Name >= firstId) firstId = (int)r.Name + 1;
        foreach (var r in groups) if (!UpdateResource(h, (IntPtr)RT_GROUP_ICON, NamePtr(r.Name), r.Lang, null, 0)) throw new Exception("del group " + r.Name + "/" + r.Lang + " " + Marshal.GetLastWin32Error());
        foreach (var r in versions) if (!UpdateResource(h, (IntPtr)RT_VERSION, NamePtr(r.Name), r.Lang, null, 0)) throw new Exception("del version " + r.Name + "/" + r.Lang + " " + Marshal.GetLastWin32Error());

        object groupName = groups.Count > 0 ? groups[0].Name : (object)1;
        ushort lang = groups.Count > 0 ? groups[0].Lang : (ushort)1033;
        var grp = new MemoryStream(); var g = new BinaryWriter(grp);
        g.Write((ushort)0); g.Write((ushort)1); g.Write((ushort)count);
        for (int i = 0; i < count; i++) {
            int e = 6 + i * 16;
            int size = BitConverter.ToInt32(icoData, e + 8), offset = BitConverter.ToInt32(icoData, e + 12);
            byte[] img = new byte[size];
            Array.Copy(icoData, offset, img, 0, size);
            if (!UpdateResource(h, (IntPtr)RT_ICON, (IntPtr)(firstId + i), lang, img, (uint)size)) throw new Exception("icon " + Marshal.GetLastWin32Error());
            g.Write(icoData, e, 12); // width, height, colours, reserved, planes, bit count, bytes in resource
            g.Write((ushort)(firstId + i));
        }
        byte[] gb = grp.ToArray();
        if (!UpdateResource(h, (IntPtr)RT_GROUP_ICON, NamePtr(groupName), lang, gb, (uint)gb.Length)) throw new Exception("group " + Marshal.GetLastWin32Error());

        var parts = version.Split('.');
        var v = new ushort[4];
        for (int i = 0; i < 4; i++) v[i] = i < parts.Length ? ushort.Parse(parts[i]) : (ushort)0;
        byte[] vi = VersionInfo(name, company, Path.GetFileName(exe), v);
        ushort vlang = versions.Count > 0 ? versions[0].Lang : (ushort)1033;
        if (!UpdateResource(h, (IntPtr)RT_VERSION, (IntPtr)1, vlang, vi, (uint)vi.Length)) throw new Exception("version " + Marshal.GetLastWin32Error());
        if (!EndUpdateResource(h, false)) throw new Exception("EndUpdateResource failed " + Marshal.GetLastWin32Error());
    }
}
'@
[ExeBrand]::Apply((Resolve-Path $Exe).Path, (Resolve-Path $Ico).Path, $Name, $Company, $Version)
Write-Output "branded: $Exe"
