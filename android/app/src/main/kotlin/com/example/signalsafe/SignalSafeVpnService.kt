package com.example.signalsafe

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.Collections
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * SignalSafeVpnService
 * 
 * Local on-device VPN service implementing an AdGuard-style DNS sinkhole:
 *  1. Establishes a virtual TUN interface on 10.240.0.1/32
 *  2. Routes DNS queries (10.240.0.1:53) into the TUN interface
 *  3. Non-DNS traffic routes directly to the physical network at full native speed
 *  4. Malicious domains in the SignalSafe blocklist are immediately sinkholed to 0.0.0.0
 *  5. Benign queries are forwarded to upstream DNS (1.1.1.1 / 8.8.8.8) using protected sockets
 *  6. Telemetry events (blocked & resolved queries) stream in real-time to Flutter
 */
class SignalSafeVpnService : VpnService() {

    companion object {
        private const val TAG = "SignalSafeVPN"
        const val ACTION_START = "com.example.signalsafe.START_VPN"
        const val ACTION_STOP = "com.example.signalsafe.STOP_VPN"
        const val ACTION_UPDATE_BLOCKLIST = "com.example.signalsafe.UPDATE_BLOCKLIST"
        const val EXTRA_BLOCKED_DOMAINS = "blocked_domains"

        private const val CHANNEL_ID = "signalsafe_vpn_channel"
        private const val NOTIFICATION_ID = 2026

        const val TUN_IP = "10.240.0.1"
        const val TUN_PREFIX = 32

        @Volatile
        var isRunning: Boolean = false
            private set

        var onDnsEventListener: ((Map<String, Any>) -> Unit)? = null
        var onStatusChangeListener: ((Boolean) -> Unit)? = null

        val activeBlockedDomains: MutableSet<String> = Collections.synchronizedSet(HashSet<String>())
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnThread: Thread? = null
    private val isStopping = AtomicBoolean(false)
    private val forwarderPool = Executors.newFixedThreadPool(6)

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START

        when (action) {
            ACTION_STOP -> {
                stopVpn()
                return START_NOT_STICKY
            }
            ACTION_UPDATE_BLOCKLIST -> {
                val list = intent?.getStringArrayListExtra(EXTRA_BLOCKED_DOMAINS)
                if (list != null) {
                    activeBlockedDomains.clear()
                    for (d in list) {
                        activeBlockedDomains.add(d.trim().lowercase())
                    }
                    Log.i(TAG, "Blocklist updated: ${activeBlockedDomains.size} domains active.")
                }
                return START_STICKY
            }
            ACTION_START -> {
                val list = intent?.getStringArrayListExtra(EXTRA_BLOCKED_DOMAINS)
                if (list != null && list.isNotEmpty()) {
                    activeBlockedDomains.clear()
                    for (d in list) {
                        activeBlockedDomains.add(d.trim().lowercase())
                    }
                }
                startVpn()
                return START_STICKY
            }
        }
        return START_NOT_STICKY
    }

    private fun startVpn() {
        if (isRunning) return
        isStopping.set(false)

        try {
            val notification = buildForegroundNotification()
            startForeground(NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.w(TAG, "Foreground notification start warning: ${e.message}")
        }

        vpnThread = Thread({
            runVpnLoop()
        }, "SignalSafeVpnWorker")
        vpnThread?.start()
    }

    private fun stopVpn() {
        if (!isRunning && isStopping.get()) return
        isStopping.set(true)
        isRunning = false

        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing VPN interface", e)
        }
        vpnInterface = null

        vpnThread?.interrupt()
        vpnThread = null

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
            // Ignored on older Android
        }

        onStatusChangeListener?.invoke(false)
        stopSelf()
        Log.i(TAG, "SignalSafe Local VPN stopped.")
    }

    private fun runVpnLoop() {
        try {
            val builder = Builder()
                .setSession("SignalSafe Local VPN")
                .setMtu(1500)
                .addAddress(TUN_IP, TUN_PREFIX)
                .addDnsServer(TUN_IP)
                .addRoute(TUN_IP, TUN_PREFIX)
                .setBlocking(true)

            vpnInterface = builder.establish()
            if (vpnInterface == null) {
                Log.e(TAG, "Failed to establish VPN interface (builder returned null).")
                stopVpn()
                return
            }

            isRunning = true
            onStatusChangeListener?.invoke(true)
            Log.i(TAG, "SignalSafe Local VPN established on $TUN_IP/32. Intercepting DNS port 53.")

            val pfd = vpnInterface!!
            val vpnInput = FileInputStream(pfd.fileDescriptor)
            val vpnOutput = FileOutputStream(pfd.fileDescriptor)

            val packetBuffer = ByteArray(32767)

            while (isRunning && !isStopping.get() && !Thread.currentThread().isInterrupted) {
                val length = try {
                    vpnInput.read(packetBuffer)
                } catch (e: Exception) {
                    if (isStopping.get()) break
                    Log.w(TAG, "VPN read error: ${e.message}")
                    break
                }

                if (length <= 0) continue

                // Process the raw IP packet
                handleIncomingPacket(packetBuffer, length, vpnOutput)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Unhandled exception in VPN loop", e)
        } finally {
            stopVpn()
        }
    }

    private fun handleIncomingPacket(packet: ByteArray, length: Int, vpnOutput: FileOutputStream) {
        // Minimum IPv4 (20 bytes) + UDP (8 bytes) + DNS header (12 bytes) = 40 bytes
        if (length < 40) return

        // Verify IPv4
        val version = (packet[0].toInt() and 0xF0) shr 4
        if (version != 4) return

        val ihl = (packet[0].toInt() and 0x0F) * 4
        if (ihl < 20 || ihl + 8 > length) return

        // Check protocol: 17 = UDP
        val protocol = packet[9].toInt() and 0xFF
        if (protocol != 17) return

        // Check destination port: 53 (DNS)
        val dstPort = ((packet[ihl + 2].toInt() and 0xFF) shl 8) or (packet[ihl + 3].toInt() and 0xFF)
        if (dstPort != 53) return

        val srcPort = ((packet[ihl].toInt() and 0xFF) shl 8) or (packet[ihl + 1].toInt() and 0xFF)
        val udpLength = ((packet[ihl + 4].toInt() and 0xFF) shl 8) or (packet[ihl + 5].toInt() and 0xFF)
        val dnsOffset = ihl + 8
        val dnsPayloadLength = udpLength - 8

        if (dnsPayloadLength < 12 || dnsOffset + dnsPayloadLength > length) return

        // Extract client IP address from IP header
        val clientIp = String.format(
            "%d.%d.%d.%d",
            packet[12].toInt() and 0xFF,
            packet[13].toInt() and 0xFF,
            packet[14].toInt() and 0xFF,
            packet[15].toInt() and 0xFF
        )

        // DNS header parsing
        val flags0 = packet[dnsOffset + 2].toInt() and 0xFF
        val isQuery = (flags0 and 0x80) == 0
        if (!isQuery) return // only handle queries

        val qdCount = ((packet[dnsOffset + 4].toInt() and 0xFF) shl 8) or (packet[dnsOffset + 5].toInt() and 0xFF)
        if (qdCount < 1) return

        // Parse Question Section
        val qOffset = dnsOffset + 12
        val parseResult = parseDnsQuestion(packet, qOffset, dnsOffset + dnsPayloadLength) ?: return
        val domain = parseResult.domain
        val qType = parseResult.qType
        val questionLength = parseResult.bytesRead

        val blocked = isDomainBlocked(domain)

        if (blocked) {
            // DNS SINKHOLE: Return 0.0.0.0 immediately
            sinkholeDnsQuery(
                packet = packet,
                ihl = ihl,
                clientIpBytes = packet.copyOfRange(12, 16),
                clientPort = srcPort,
                dnsOffset = dnsOffset,
                qOffset = qOffset,
                questionLength = questionLength,
                qType = qType,
                domain = domain,
                clientIp = clientIp,
                vpnOutput = vpnOutput
            )
        } else {
            // ALLOWED: Forward upstream to 1.1.1.1 / 8.8.8.8
            val rawDnsPayload = packet.copyOfRange(dnsOffset, dnsOffset + dnsPayloadLength)
            forwardDnsQueryUpstream(
                rawDnsQuery = rawDnsPayload,
                clientIpBytes = packet.copyOfRange(12, 16),
                clientPort = srcPort,
                domain = domain,
                clientIp = clientIp,
                qType = qType,
                vpnOutput = vpnOutput
            )
        }
    }

    private data class ParsedQuestion(val domain: String, val qType: Int, val bytesRead: Int)

    private fun parseDnsQuestion(data: ByteArray, startOffset: Int, limit: Int): ParsedQuestion? {
        var cur = startOffset
        val sb = StringBuilder()

        while (cur < limit) {
            val len = data[cur].toInt() and 0xFF
            if (len == 0) {
                cur++
                break
            }
            if (len > 63 || cur + 1 + len > limit) return null
            cur++
            if (sb.isNotEmpty()) sb.append('.')
            for (i in 0 until len) {
                sb.append(data[cur + i].toInt().toChar())
            }
            cur += len
        }

        if (cur + 4 > limit) return null
        val qType = ((data[cur].toInt() and 0xFF) shl 8) or (data[cur + 1].toInt() and 0xFF)
        // val qClass = ((data[cur + 2].toInt() and 0xFF) shl 8) or (data[cur + 3].toInt() and 0xFF)
        cur += 4

        val totalQuestionBytes = cur - startOffset
        return ParsedQuestion(sb.toString().lowercase(), qType, totalQuestionBytes)
    }

    private fun isDomainBlocked(domain: String): Boolean {
        if (domain.isEmpty()) return false
        val clean = domain.trim().lowercase().removeSuffix(".")
        if (activeBlockedDomains.contains(clean)) return true

        // Check parent domains (e.g. sub.phish.com -> phish.com)
        var dotIndex = clean.indexOf('.')
        while (dotIndex != -1) {
            val parent = clean.substring(dotIndex + 1)
            if (activeBlockedDomains.contains(parent)) return true
            dotIndex = clean.indexOf('.', dotIndex + 1)
        }
        return false
    }

    /**
     * Builds and writes an immediate DNS response with 0.0.0.0 for blocked domains
     */
    private fun sinkholeDnsQuery(
        packet: ByteArray,
        ihl: Int,
        clientIpBytes: ByteArray,
        clientPort: Int,
        dnsOffset: Int,
        qOffset: Int,
        questionLength: Int,
        qType: Int,
        domain: String,
        clientIp: String,
        vpnOutput: FileOutputStream
    ) {
        val isAQuery = (qType == 1)
        val answerLength = if (isAQuery) 16 else 0
        val dnsRespLen = 12 + questionLength + answerLength
        val dnsResp = ByteArray(dnsRespLen)

        var p = 0
        // Transaction ID
        dnsResp[p++] = packet[dnsOffset]
        dnsResp[p++] = packet[dnsOffset + 1]
        // Flags: QR=1 (Response), AA=1, RD=1, RA=1, RCODE=0 (No error)
        dnsResp[p++] = 0x85.toByte()
        dnsResp[p++] = 0x80.toByte()
        // QDCOUNT: 1
        dnsResp[p++] = 0x00
        dnsResp[p++] = 0x01
        // ANCOUNT: 1 if A query, 0 otherwise
        dnsResp[p++] = 0x00
        dnsResp[p++] = if (isAQuery) 0x01 else 0x00
        // NSCOUNT: 0
        dnsResp[p++] = 0x00
        dnsResp[p++] = 0x00
        // ARCOUNT: 0
        dnsResp[p++] = 0x00
        dnsResp[p++] = 0x00

        // Copy Question section
        System.arraycopy(packet, qOffset, dnsResp, p, questionLength)
        p += questionLength

        // Answer Section: A Record -> 0.0.0.0
        if (isAQuery) {
            // Pointer to QNAME at byte 12 (0xC00C)
            dnsResp[p++] = 0xC0.toByte()
            dnsResp[p++] = 0x0C
            // TYPE: A (1)
            dnsResp[p++] = 0x00
            dnsResp[p++] = 0x01
            // CLASS: IN (1)
            dnsResp[p++] = 0x00
            dnsResp[p++] = 0x01
            // TTL: 60 seconds
            dnsResp[p++] = 0x00
            dnsResp[p++] = 0x00
            dnsResp[p++] = 0x00
            dnsResp[p++] = 0x3C
            // RDLENGTH: 4 bytes
            dnsResp[p++] = 0x00
            dnsResp[p++] = 0x04
            // RDATA: 0.0.0.0
            dnsResp[p++] = 0x00
            dnsResp[p++] = 0x00
            dnsResp[p++] = 0x00
            dnsResp[p++] = 0x00
        }

        // Construct complete IPv4 + UDP packet
        val fullPacket = assembleIpUdpPacket(
            dnsPayload = dnsResp,
            srcIpBytes = byteArrayOf(10, 240.toByte(), 0, 1),
            dstIpBytes = clientIpBytes,
            srcPort = 53,
            dstPort = clientPort
        )

        try {
            synchronized(vpnOutput) {
                vpnOutput.write(fullPacket)
            }
            Log.d(TAG, "BLOCKED -> $domain (sinkholed to 0.0.0.0 for $clientIp)")

            // Stream block event to Flutter
            val event = mapOf(
                "type" to "blocked",
                "domain" to domain,
                "clientIp" to clientIp,
                "qType" to qType,
                "timestamp" to System.currentTimeMillis()
            )
            onDnsEventListener?.invoke(event)
        } catch (e: Exception) {
            Log.e(TAG, "Error writing sinkhole packet", e)
        }
    }

    /**
     * Forwards an allowed DNS query to upstream public DNS using a protected socket
     */
    private fun forwardDnsQueryUpstream(
        rawDnsQuery: ByteArray,
        clientIpBytes: ByteArray,
        clientPort: Int,
        domain: String,
        clientIp: String,
        qType: Int,
        vpnOutput: FileOutputStream
    ) {
        forwarderPool.submit {
            var socket: DatagramSocket? = null
            try {
                socket = DatagramSocket()
                protect(socket) // Critical: socket bypasses TUN interface
                socket.soTimeout = 2500

                val upstreamServers = arrayOf("1.1.1.1", "8.8.8.8", "1.0.0.1")
                var resolved = false

                for (server in upstreamServers) {
                    try {
                        val address = InetAddress.getByName(server)
                        val sendPacket = DatagramPacket(rawDnsQuery, rawDnsQuery.size, address, 53)
                        socket.send(sendPacket)

                        val recvBuf = ByteArray(4096)
                        val recvPacket = DatagramPacket(recvBuf, recvBuf.size)
                        socket.receive(recvPacket)

                        val respPayload = recvPacket.data.copyOfRange(0, recvPacket.length)
                        val fullPacket = assembleIpUdpPacket(
                            dnsPayload = respPayload,
                            srcIpBytes = byteArrayOf(10, 240.toByte(), 0, 1),
                            dstIpBytes = clientIpBytes,
                            srcPort = 53,
                            dstPort = clientPort
                        )

                        synchronized(vpnOutput) {
                            vpnOutput.write(fullPacket)
                        }

                        val event = mapOf(
                            "type" to "resolved",
                            "domain" to domain,
                            "clientIp" to clientIp,
                            "qType" to qType,
                            "timestamp" to System.currentTimeMillis()
                        )
                        onDnsEventListener?.invoke(event)
                        resolved = true
                        break
                    } catch (e: Exception) {
                        // try next upstream server
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Upstream forward error for $domain: ${e.message}")
            } finally {
                socket?.close()
            }
        }
    }

    /**
     * Wraps a DNS payload inside standard IPv4 and UDP headers with RFC checksums
     */
    private fun assembleIpUdpPacket(
        dnsPayload: ByteArray,
        srcIpBytes: ByteArray,
        dstIpBytes: ByteArray,
        srcPort: Int,
        dstPort: Int
    ): ByteArray {
        val totalLen = 28 + dnsPayload.size
        val packet = ByteArray(totalLen)

        // --- IPv4 Header (20 bytes) ---
        packet[0] = 0x45.toByte() // Version 4, IHL 5
        packet[1] = 0x00 // TOS
        packet[2] = ((totalLen shr 8) and 0xFF).toByte()
        packet[3] = (totalLen and 0xFF).toByte()
        val id = (System.currentTimeMillis() and 0xFFFF).toInt()
        packet[4] = ((id shr 8) and 0xFF).toByte()
        packet[5] = (id and 0xFF).toByte()
        packet[6] = 0x40.toByte() // Don't fragment
        packet[7] = 0x00
        packet[8] = 64.toByte() // TTL
        packet[9] = 17.toByte() // UDP
        packet[10] = 0x00 // Checksum placeholder
        packet[11] = 0x00

        System.arraycopy(srcIpBytes, 0, packet, 12, 4)
        System.arraycopy(dstIpBytes, 0, packet, 16, 4)

        val ipChecksum = calculateChecksum(packet, 0, 20)
        packet[10] = ((ipChecksum shr 8) and 0xFF).toByte()
        packet[11] = (ipChecksum and 0xFF).toByte()

        // --- UDP Header (8 bytes) ---
        packet[20] = ((srcPort shr 8) and 0xFF).toByte()
        packet[21] = (srcPort and 0xFF).toByte()
        packet[22] = ((dstPort shr 8) and 0xFF).toByte()
        packet[23] = (dstPort and 0xFF).toByte()

        val udpLen = 8 + dnsPayload.size
        packet[24] = ((udpLen shr 8) and 0xFF).toByte()
        packet[25] = (udpLen and 0xFF).toByte()
        packet[26] = 0x00 // UDP checksum is optional in IPv4
        packet[27] = 0x00

        // --- DNS Payload ---
        System.arraycopy(dnsPayload, 0, packet, 28, dnsPayload.size)

        return packet
    }

    private fun calculateChecksum(buf: ByteArray, offset: Int, length: Int): Int {
        var sum = 0
        var i = offset
        while (i < offset + length - 1) {
            val word = ((buf[i].toInt() and 0xFF) shl 8) or (buf[i + 1].toInt() and 0xFF)
            sum += word
            i += 2
        }
        if (i < offset + length) {
            sum += (buf[i].toInt() and 0xFF) shl 8
        }
        while ((sum shr 16) > 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }
        return sum.inv() and 0xFFFF
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SignalSafe Local VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows SignalSafe local DNS filter status"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildForegroundNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("SignalSafe Local VPN Active")
            .setContentText("DNS sinkhole filtering device traffic")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopVpn()
        forwarderPool.shutdownNow()
    }
}
