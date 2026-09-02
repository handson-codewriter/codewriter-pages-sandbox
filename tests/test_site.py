import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INDEX = os.path.join(ROOT, "index.html")


class TestSite(unittest.TestCase):
    def setUp(self):
        with open(INDEX, encoding="utf-8") as f:
            self.html = f.read()

    def test_html_structuur(self):
        self.assertIn("<title>", self.html)
        self.assertRegex(self.html, r"<h1[^>]*>.*Codewriter Lab.*</h1>")
        self.assertIn(
            '<meta name="build-sha" content="__BUILD_SHA__">', self.html
        )
        self.assertRegex(
            self.html, re.compile(r"<footer>.*build __BUILD_SHA__.*</footer>", re.DOTALL)
        )
        links = re.findall(r'href="(https?://[^"]+)"', self.html)
        self.assertEqual(
            links,
            ["https://github.com/handson-codewriter/codewriter-pages-sandbox"],
        )

    def test_titel_en_h1(self):
        self.assertRegex(self.html, r"<title>\s*Codewriter Lab\s*</title>")
        self.assertRegex(self.html, r"<h1[^>]*>\s*Codewriter Lab\s*</h1>")
        h1_matches = re.findall(r"<h1\b", self.html)
        self.assertEqual(len(h1_matches), 1)

    def test_doeltekst(self):
        self.assertIn(
            "Deze site is autonoom gebouwd en gepubliceerd door de codewriter-bouwlijn.",
            self.html,
        )

    def test_meta_description(self):
        metas = re.findall(r'<meta name="description" content="([^"]*)">', self.html)
        self.assertEqual(len(metas), 1)
        self.assertEqual(
            metas[0],
            "Een statische pagina die de codewriter-bouwlijn autonoom bouwt, test en publiceert.",
        )


if __name__ == "__main__":
    unittest.main()
