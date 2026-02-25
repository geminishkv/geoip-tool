# Burp Extender (Jython 2.7):
# - добавляет вкладку "GeoIP" в Message Editor
# - берёт host из URL запроса
# - резолвит host -> IP (чтобы работать "только по IP")
# - вызывает локальную утилиту: geoip json <ip>
# - показывает stdout (pretty JSON) и при необходимости stderr/ ошибки

from burp import IBurpExtender, IMessageEditorTabFactory, IMessageEditorTab

from java.io import PrintWriter, BufferedReader, InputStreamReader
from java.lang import Runtime
from java.net import InetAddress
from java.awt import BorderLayout
from javax.swing import JPanel, JScrollPane, JTextArea

import json


class BurpExtender(IBurpExtender, IMessageEditorTabFactory):

    def registerExtenderCallbacks(self, callbacks):
        self._callbacks = callbacks
        self._helpers = callbacks.getHelpers()
        self._stdout = PrintWriter(callbacks.getStdout(), True)
        self._stderr = PrintWriter(callbacks.getStderr(), True)

        callbacks.setExtensionName("GeoIP Tab (geoip-tool)")
        callbacks.registerMessageEditorTabFactory(self)

        self._stdout.println("[GeoIP] Extension loaded. Make sure `geoip` is in PATH.")
        return

    def createNewInstance(self, controller, editable):
        return GeoIpTab(self._callbacks, self._helpers, controller)


class GeoIpTab(IMessageEditorTab):

    def __init__(self, callbacks, helpers, controller):
        self._callbacks = callbacks
        self._helpers = helpers
        self._controller = controller

        self._panel = JPanel(BorderLayout())
        self._text = JTextArea()
        self._text.setEditable(False)

        scroll = JScrollPane(self._text)
        self._panel.add(scroll, BorderLayout.CENTER)

    def getTabCaption(self):
        return "GeoIP"

    def getUiComponent(self):
        return self._panel

    def isEnabled(self, content, isRequest):
        # включаем вкладку только для запросов
        return isRequest

    def _read_stream(self, stream):
        reader = BufferedReader(InputStreamReader(stream, "UTF-8"))
        lines = []
        line = reader.readLine()
        while line is not None:
            lines.append(line)
            line = reader.readLine()
        reader.close()
        return "\n".join(lines)

    def setMessage(self, content, isRequest):
        if content is None or not isRequest:
            self._text.setText("")
            return

        try:
            try:
                req_info = self._helpers.analyzeRequest(self._controller.getHttpService(), content)
            except:
                req_info = self._helpers.analyzeRequest(content)

            url = req_info.getUrl()
            if url is None:
                self._text.setText("No URL")
                return

            host = url.getHost()
            if host is None:
                self._text.setText("No host")
                return

            try:
                ip = InetAddress.getByName(host).getHostAddress()
            except Exception as e:
                self._text.setText("DNS resolve failed for host: %s\n\n%s" % (host, str(e)))
                return

            cmd = ["geoip", "json", ip]
            proc = Runtime.getRuntime().exec(cmd)

            stdout_text = self._read_stream(proc.getInputStream())
            stderr_text = self._read_stream(proc.getErrorStream())
            exit_code = proc.waitFor()

            data = (stdout_text or "").strip()

            if not data:
                msg = "No data from geoip (exit code %s)\nIP: %s" % (str(exit_code), ip)
                if stderr_text and stderr_text.strip():
                    msg += "\n\nstderr:\n" + stderr_text.strip()
                self._text.setText(msg)
                return

            try:
                j = json.loads(data)
                pretty = json.dumps(j, indent=2, ensure_ascii=False)
                if stderr_text and stderr_text.strip():
                    pretty += "\n\n--- stderr ---\n" + stderr_text.strip()
                self._text.setText(pretty)
            except Exception:
                # Если geoip вернул не-JSON (или JSON повреждён), покажем как есть
                msg = "Invalid JSON from geoip (exit code %s)\nIP: %s\n\nstdout:\n%s" % (str(exit_code), ip, data)
                if stderr_text and stderr_text.strip():
                    msg += "\n\nstderr:\n" + stderr_text.strip()
                self._text.setText(msg)

        except Exception as e:
            self._text.setText("Error: %s" % str(e))

    def getMessage(self):
        return None

    def isModified(self):
        return False

    def getSelectedData(self):
        return None