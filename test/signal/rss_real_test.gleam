import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import zeitgeist/signal/rss

pub fn main() {
  gleeunit.main()
}

// ---------------------------------------------------------------------------
// Sample RSS 2.0
// ---------------------------------------------------------------------------

const sample_rss = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<rss version=\"2.0\">
  <channel>
    <title>Test Feed</title>
    <item>
      <title>First Article</title>
      <link>https://example.com/1</link>
      <description>Summary of the first article</description>
    </item>
    <item>
      <title>Second Article</title>
      <link>https://example.com/2</link>
      <description>Summary of the second article</description>
    </item>
  </channel>
</rss>"

// ---------------------------------------------------------------------------
// Sample Atom
// ---------------------------------------------------------------------------

const sample_atom = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<feed xmlns=\"http://www.w3.org/2005/Atom\">
  <title>Atom Test Feed</title>
  <entry>
    <title>Atom Entry One</title>
    <link href=\"https://example.com/atom/1\" rel=\"alternate\" />
    <summary>Summary of atom entry one</summary>
  </entry>
  <entry>
    <title>Atom Entry Two</title>
    <link href=\"https://example.com/atom/2\" />
    <summary>Summary of atom entry two</summary>
  </entry>
</feed>"

// ---------------------------------------------------------------------------
// Sample with CDATA and HTML in descriptions
// ---------------------------------------------------------------------------

const sample_rss_html = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<rss version=\"2.0\">
  <channel>
    <item>
      <title>HTML Article</title>
      <link>https://example.com/html</link>
      <description><![CDATA[<p>This has <strong>HTML</strong> tags &amp; entities</p>]]></description>
    </item>
  </channel>
</rss>"

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

pub fn rss_items_parsed_test() {
  let assert Ok(items) = rss.parse_xml(sample_rss)
  should.equal(list.length(items), 2)
  let assert [first, second] = items
  should.equal(first.title, "First Article")
  should.equal(first.link, "https://example.com/1")
  should.equal(second.title, "Second Article")
}

pub fn rss_item_description_parsed_test() {
  let assert Ok(items) = rss.parse_xml(sample_rss)
  let assert [first, ..] = items
  should.be_true(string.contains(first.description, "first article"))
}

pub fn atom_entries_parsed_test() {
  let assert Ok(items) = rss.parse_xml(sample_atom)
  should.equal(list.length(items), 2)
  let assert [first, second] = items
  should.equal(first.title, "Atom Entry One")
  should.equal(second.title, "Atom Entry Two")
}

pub fn atom_link_href_extracted_test() {
  let assert Ok(items) = rss.parse_xml(sample_atom)
  let assert [first, ..] = items
  should.equal(first.link, "https://example.com/atom/1")
}

pub fn empty_xml_returns_empty_list_test() {
  let assert Ok(items) = rss.parse_xml("<rss><channel></channel></rss>")
  should.equal(items, [])
}

pub fn html_stripped_from_descriptions_test() {
  let assert Ok(items) = rss.parse_xml(sample_rss_html)
  let assert [item] = items
  // HTML tags should be stripped
  should.be_false(string.contains(item.description, "<p>"))
  should.be_false(string.contains(item.description, "<strong>"))
  // Text content should remain
  should.be_true(string.contains(item.description, "HTML"))
  should.be_true(string.contains(item.description, "tags"))
}

pub fn html_entities_decoded_test() {
  let assert Ok(items) = rss.parse_xml(sample_rss_html)
  let assert [item] = items
  // &amp; should become &
  should.be_true(string.contains(item.description, "&"))
  should.be_false(string.contains(item.description, "&amp;"))
}
