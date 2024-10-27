// WSNA.cpp : main project file.

#include "stdafx.h"
#include "iostream"

#using <System.dll>

using namespace System;
using namespace System::IO::Ports;
using namespace System::Threading;

public ref class SerialPortComm
{
private:
    static bool _continue;
    static SerialPort^ _serialPort;
	static int sLen;
	static cli::array<unsigned char> ^sBuff;
	static Timer^ stateTimer;
	static bool pause;

	static int packetLen;
	static unsigned int packetType;
	static unsigned int packetSrc;
	static unsigned int packetDst;
	static unsigned int packetDur;
	static unsigned int packetSeq;
	static unsigned int packetSleeptime;

public:
	ref class StatusChecker {
	public:
		void CheckStatus(Object^ stateInfo) {
			AutoResetEvent^ autoEvent = dynamic_cast<AutoResetEvent^>(stateInfo);
			autoEvent->Set();
			stateTimer->Change(System::Threading::Timeout::Infinite, System::Threading::Timeout::Infinite);
			if (sLen >= packetLen + 1) {				
				pause = true;
				DateTime now = DateTime::Now;
				Console::Write(now.ToString("yyyy-MM-dd HH:mm:ss"));
				Console::Write(" [ ");
				for (int i = 0; i < sLen; i++)
					printf("%02x ", (unsigned char)(sBuff->GetValue(i)));
				printf("]\n");
				
				packetType = (unsigned char)(sBuff->GetValue(1));
				if (packetType = 1) {
					packetSrc = ((unsigned char)(sBuff->GetValue(2)) << 8) + (unsigned char)(sBuff->GetValue(3));
					packetSeq = (unsigned char)(sBuff->GetValue(4));
					packetSleeptime = ((unsigned char)(sBuff->GetValue(5)) << 8) + (unsigned char)(sBuff->GetValue(6));
					printf("SYNC - Source address: %u, Sequence number: %u, Sleep time: %u ms\n", packetSrc, packetSeq, 10*packetSleeptime); 
				}

				sLen = 0;
				packetLen = 0;
				pause = false;
			}
			stateTimer->Change(50, 50);
		}
	};

    static void Main()
    {
		sBuff = gcnew array<unsigned char>(256);
		sLen = 0;

        String^ message;
        StringComparer^ stringComparer = StringComparer::OrdinalIgnoreCase;
        Thread^ readThread = gcnew Thread(gcnew ThreadStart(SerialPortComm::Read));

        // Create a new SerialPort object with default settings.
        _serialPort = gcnew SerialPort();

        // Allow the user to set the appropriate properties.
        _serialPort->PortName = SetPortName(_serialPort->PortName);
        _serialPort->BaudRate = SetPortBaudRate(_serialPort->BaudRate);
        _serialPort->Parity = SetPortParity(_serialPort->Parity);
        _serialPort->DataBits = SetPortDataBits(_serialPort->DataBits);
        _serialPort->StopBits = SetPortStopBits(_serialPort->StopBits);
        _serialPort->Handshake = SetPortHandshake(_serialPort->Handshake);

        // Set the read/write timeouts
        _serialPort->ReadTimeout = 500;
        _serialPort->WriteTimeout = 500;

        _serialPort->Open();
        _continue = true;
        readThread->Start();

        Console::WriteLine("Type QUIT to exit");

		AutoResetEvent^ autoEvent = gcnew AutoResetEvent(false);
		StatusChecker^ statusChecker = gcnew StatusChecker();
		TimerCallback^ tcb = gcnew TimerCallback(statusChecker, &SerialPortComm::StatusChecker::CheckStatus);
		stateTimer = gcnew Timer(tcb, autoEvent, 50, 50);

        while (_continue)
        {
            message = Console::ReadLine();

            if (stringComparer->Equals("quit", message))
            {
                _continue = false;
            }
        }

        readThread->Join();
        _serialPort->Close();
    }

    static void Read()
    {
        while (_continue)
        {
            try
            {
				int r = _serialPort->ReadByte();
				
				if (!pause)
					stateTimer->Change(50, 50);

				if (sLen == 0)
					packetLen = r;

				if (sLen < 256)
					sBuff->SetValue((unsigned char)r, sLen++);				
            }
            catch (TimeoutException ^) { }
        }
    }

    static String^ SetPortName(String^ defaultPortName)
    {
        String^ portName;

        Console::WriteLine("Available Ports:");
        for each (String^ s in SerialPort::GetPortNames())
        {
            Console::WriteLine("   {0}", s);
        }

        Console::Write("COM port({0}): ", defaultPortName);
        portName = Console::ReadLine();

        if (portName == "")
        {
            portName = defaultPortName;
        }
        return portName;
    }

    static Int32 SetPortBaudRate(Int32 defaultPortBaudRate)
    {
        String^ baudRate;

        Console::Write("Baud Rate({0}): ", defaultPortBaudRate);
        baudRate = Console::ReadLine();

        if (baudRate == "")
        {
            baudRate = defaultPortBaudRate.ToString();
        }

        return Int32::Parse(baudRate);
    }

    static Parity SetPortParity(Parity defaultPortParity)
    {
        String^ parity;

        Console::WriteLine("Available Parity options:");
        for each (String^ s in Enum::GetNames(Parity::typeid))
        {
            Console::WriteLine("   {0}", s);
        }

        Console::Write("Parity({0}):", defaultPortParity.ToString());
        parity = Console::ReadLine();

        if (parity == "")
        {
            parity = defaultPortParity.ToString();
        }

        return (Parity)Enum::Parse(Parity::typeid, parity);
    }

    static Int32 SetPortDataBits(Int32 defaultPortDataBits)
    {
        String^ dataBits;

        Console::Write("Data Bits({0}): ", defaultPortDataBits);
        dataBits = Console::ReadLine();

        if (dataBits == "")
        {
            dataBits = defaultPortDataBits.ToString();
        }

        return Int32::Parse(dataBits);
    }

    static StopBits SetPortStopBits(StopBits defaultPortStopBits)
    {
        String^ stopBits;

        Console::WriteLine("Available Stop Bits options:");
        for each (String^ s in Enum::GetNames(StopBits::typeid))
        {
            Console::WriteLine("   {0}", s);
        }

        Console::Write("Stop Bits({0}):", defaultPortStopBits.ToString());
        stopBits = Console::ReadLine();

        if (stopBits == "")
        {
            stopBits = defaultPortStopBits.ToString();
        }

        return (StopBits)Enum::Parse(StopBits::typeid, stopBits);
    }

    static Handshake SetPortHandshake(Handshake defaultPortHandshake)
    {
        String^ handshake;

        Console::WriteLine("Available Handshake options:");
        for each (String^ s in Enum::GetNames(Handshake::typeid))
        {
            Console::WriteLine("   {0}", s);
        }

        Console::Write("Handshake({0}):", defaultPortHandshake.ToString());
        handshake = Console::ReadLine();

        if (handshake == "")
        {
            handshake = defaultPortHandshake.ToString();
        }

        return (Handshake)Enum::Parse(Handshake::typeid, handshake);
    }
};

int main(array<System::String ^> ^args)
{
    SerialPortComm::Main();
    return 0;
}
