import 'package:flutter_test/flutter_test.dart';
import 'package:podavio/data/analysis_overview.dart';
import 'package:podavio/data/hosting_source.dart';
import 'package:podavio/data/skip_segments.dart';

void main() {
  test('a podcast with no download is hidden and one download is shown', () {
    final rows = buildAnalysisOverview(
      catalog: const [
        AnalysisCatalogPodcast(id: 1, title: 'Suivi sans fichier'),
        AnalysisCatalogPodcast(
          id: 2,
          title: 'Un seul fichier',
          feedUrl: 'https://feeds.audiomeans.fr/show.xml',
        ),
      ],
      downloads: const [
        AnalysisDownloadFact(
          podcastId: 2,
          audioUrl: 'https://audio.audiomeans.fr/un.mp3',
          fingerprintStatus: '',
        ),
      ],
      segments: const [
        AnalysisSegmentFact(podcastId: 2, kind: SkipSegmentKind.ad, count: 2),
        AnalysisSegmentFact(podcastId: 1, kind: SkipSegmentKind.ad, count: 4),
      ],
    );

    expect(showsOnAnalysisPage(0), isFalse);
    expect(showsOnAnalysisPage(1), isTrue);
    expect(rows.map((row) => row.title), ['Un seul fichier']);
    expect(rows.single.downloadedEpisodes, 1);
    expect(rows.single.hostingSource, 'audiomeans');
    expect(rows.single.status, AnalysisOverviewStatus.pending);
    expect(rows.single.countOf(SkipSegmentKind.ad), 2);
    expect(rows.single.countOf(SkipSegmentKind.jingle), 0);
  });

  test('fingerprints group by hosting source', () {
    const hosts = <HostingDownload>[
      (
        podcastId: 1,
        audioUrl: 'https://audio.audiomeans.fr/a.mp3',
        feedUrl: 'https://feeds.audiomeans.fr/a.xml',
      ),
      (
        podcastId: 1,
        audioUrl: 'https://podcasts.audiomeans.fr/b.mp3',
        feedUrl: 'https://feeds.audiomeans.fr/a.xml',
      ),
      (
        podcastId: 2,
        audioUrl: 'https://files.audiomeans.fr/c.mp3',
        feedUrl: 'https://example.com/b.xml',
      ),
      (
        podcastId: 3,
        audioUrl: 'https://mcdn.podbean.com/d.mp3',
        feedUrl: 'https://feed.podbean.com/c.xml',
      ),
    ];

    expect(
      comparisonPodcastIds(
        focusPodcastId: 1,
        focusDownloadCount: 1,
        hosts: hosts,
      ),
      [1],
    );
    expect(
      comparisonPodcastIds(
        focusPodcastId: 1,
        focusDownloadCount: 2,
        hosts: hosts,
      ),
      [1, 2],
    );
    expect(hostingSourceKey('https://audio.audiomeans.fr/a.mp3'), 'audiomeans');
    expect(hostingSourceKey('https://www.audiomeans.fr/a'), 'audiomeans');

    final grouped = groupByHostingSource(
      hosts,
      (row) => hostingSourceKey(hostingUrlOf(row)),
    );
    expect(grouped['audiomeans']!.map((row) => row.podcastId), [1, 1, 2]);
    expect(grouped['podbean']!.single.podcastId, 3);

    final rows = buildAnalysisOverview(
      catalog: const [
        AnalysisCatalogPodcast(id: 1, title: 'Alpha'),
        AnalysisCatalogPodcast(id: 2, title: 'Bravo'),
        AnalysisCatalogPodcast(id: 3, title: 'Charlie'),
      ],
      downloads: const [
        AnalysisDownloadFact(
          podcastId: 1,
          audioUrl: 'https://audio.audiomeans.fr/a.mp3',
          fingerprintStatus: 'done',
        ),
        AnalysisDownloadFact(
          podcastId: 2,
          audioUrl: 'https://files.audiomeans.fr/c.mp3',
          fingerprintStatus: 'failed',
        ),
        AnalysisDownloadFact(
          podcastId: 3,
          audioUrl: 'https://mcdn.podbean.com/d.mp3',
          fingerprintStatus: 'done',
        ),
      ],
      segments: const [],
    );
    final groups = groupAnalysisRows(rows);
    expect(groups.map((group) => group.hostingSource), [
      'audiomeans',
      'podbean',
    ]);
    expect(groups.first.podcasts.map((row) => row.title), ['Alpha', 'Bravo']);
    expect(groups.first.podcasts.last.status, AnalysisOverviewStatus.failed);
    expect(groups.last.podcasts.single.status, AnalysisOverviewStatus.analysed);
  });

  test(
    'a running episode is in progress and a missing fingerprint is pending',
    () {
      expect(
        analysisStatus(
          fingerprintStatuses: const ['done', 'running'],
          running: false,
          queued: false,
        ),
        AnalysisOverviewStatus.inProgress,
      );
      expect(
        analysisStatus(
          fingerprintStatuses: const ['done', ''],
          running: false,
          queued: false,
        ),
        AnalysisOverviewStatus.pending,
      );
      expect(
        analysisStatus(
          fingerprintStatuses: const ['done'],
          running: true,
          queued: false,
        ),
        AnalysisOverviewStatus.inProgress,
      );
    },
  );
}
