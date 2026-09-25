// Pure, DOM-free client helpers - extracted so they can be unit-tested directly
// under Node (see spec/js/), and loaded before app.js in the browser where they
// attach to window.BTLogic (BT-112).
(function (global) {
  'use strict';

  // The trailing numeric part of a story id ("B2B-042" -> 42), so column
  // ordering is correct even when the namespace itself contains digits (BT-104).
  function storyNumber(id) {
    const m = String(id).match(/(\d+)$/);
    return m ? parseInt(m[1], 10) : 0;
  }

  // Comparator ordering stories by their trailing number.
  function byStoryNumber(a, b) {
    return storyNumber(a.id) - storyNumber(b.id);
  }

  // Resolve a relative markdown link against the directory of the page it sits
  // in, docs-root-relative. Returns null when the link is not relative or
  // climbs out of the root - the caller must refuse, not render (BT-140/BT-159).
  function resolveDocPath(pagePath, href) {
    if (/^([a-z]+:|\/|#)/i.test(href)) return null;
    const base = String(pagePath).split('/').slice(0, -1);
    for (const seg of String(href).split('/')) {
      if (seg === '' || seg === '.') continue;
      if (seg === '..') {
        if (base.length === 0) return null;
        base.pop();
      } else {
        base.push(seg);
      }
    }
    return base.join('/');
  }

  // Candidates for "which decision supersedes this one": the accepted records,
  // minus the one being superseded - a record cannot supersede itself, and
  // only an accepted record is in force to supersede anything (BT-145).
  function supersedeCandidates(records, id) {
    return records.filter((r) => r.status === 'accepted' && r.id !== id).map((r) => r.id);
  }

  // The namespace prefix of any record or story id ("TST-ADR-0004" and
  // "TST-129" are both "TST"). Cross-namespace ids render as plain text -
  // this checkout cannot resolve them either way (BT-ADR-0013), so it must
  // not offer a link that lies (BT-148).
  function idNamespace(id) {
    const m = String(id).match(/^([A-Z][A-Z0-9]*)-/);
    return m ? m[1] : null;
  }
  function sameNamespace(a, b) {
    const na = idNamespace(a);
    return na !== null && na === idNamespace(b);
  }

  // Only http(s) and mailto links leave the docs browser for the browser
  // proper; anything else (javascript:, data:, ...) is refused by the caller.
  function isExternalHref(href) {
    return /^(https?|mailto):/i.test(String(href || '').trim());
  }

  // The id in a location hash ("#TST-042" -> "TST-042"); '' when absent or
  // malformed - a bad hash must not throw at boot.
  function hashId(hash) {
    try {
      return decodeURIComponent(String(hash || '').replace(/^#/, ''));
    } catch {
      return '';
    }
  }

  const api = {
    storyNumber,
    byStoryNumber,
    resolveDocPath,
    supersedeCandidates,
    idNamespace,
    sameNamespace,
    isExternalHref,
    hashId,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else global.BTLogic = api;
})(typeof self !== 'undefined' ? self : this);
