from burp import IBurpExtender, IMessageEditorTabFactory, IMessageEditorTab
from java.io import PrintWriter
from javax.swing import JPanel, JScrollPane, JTextArea
from java.lang import Runtime

import json

class BurpExtender(IBurpExtender, IMessageEditorTabFactory):

    def registerExtenderCallbacks(self, callbacks):
        self._callbacks = callbacks
        self._helpers = callbacks.getHelpers()
        self._stdout = PrintWriter(callbacks.getStdout(), True)

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

        self._panel = JPanel()
        self._text = JTextArea()
        self._text.setEditable(False)
        scroll = JScrollPane(self._text)
        self._panel.setLayout(None)
        scroll.setBounds(0, 0, 800, 600)
        self._panel.add(scroll)

    def getTabCaption(self):
        return "GeoIP"

    def getUiComponent(self):
        return self._panel

    def isEnabled(self, content, isRequest):
        # Включаем вкладку только для запросов
        return isRequest

    def setMessage(self, content, isRequest):
        if content is None or not isRequest:
            self._text.setText("")
            return

        try:
            request_info = self._helpers.analyzeRequest(self._controller.getHttpService(), content)
            host = request_info.getUrl().getHost()
            if host is None:
                self._text.setText("No host")
                return

            # Вызов внешней команды: geoip json <host>
            cmd = ["geoip", "json", host]
            proc = Runtime.getRuntime().exec(cmd)
            input_stream = proc.getInputStream()
            output = []
            b = bytearray(1024)
            while True:
                n = input_stream.read(b)
                if n <= 0:
                    break
                output.append(str(b[:n], "utf-8"))
            input_stream.close()
            proc.waitFor()

            data = "".join(output).strip()
            if not 
                self._text.setText("No data from geoip")
                return

            try:
                j = json.loads(data)
                pretty = json.dumps(j, indent=2, ensure_ascii=False)
                self._text.setText(pretty)
            except Exception as e:
                self._text.setText("Invalid JSON from geoip:\n\n%s" % data)

        except Exception as e:
            self._text.setText("Error: %s" % str(e))

    def getMessage(self):
        return None

    def isModified(self):
        return False

    def getSelectedData(self):
        return None
