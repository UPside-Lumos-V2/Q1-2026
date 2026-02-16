// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// CrossCurve.sol은 더 이상 사용하지 않습니다.
// IncidentBase.sol로 마이그레이션되었습니다.
//
// 파일 구조:
//   IncidentBase.sol    ← 주소, 인터페이스, setUp (이 파일을 대체)
//   PoC_template.t.sol  ← exploit 로직 (직접 작성)
//   Replay.t.sol        ← calldata 리플레이
//   README.md           ← 사건 분석 보고서
//
// 이 파일은 기존 호환성을 위해 유지되며,
// IncidentBase.sol을 re-export합니다.

import "./IncidentBase.sol";
